import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/enums.dart';
import '../models/cafe_table.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/ingredient.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../models/voucher.dart';
import 'data_store.dart';
import 'outbox.dart';

/// Đồng bộ hybrid: push qua outbox RPC (money/stock), pull increment theo
/// watermark (reference data + orders). Offline -> outbox giữ nguyên, retry
/// trên reconnect. DataStore vẫn là nguồn UI; DB là nguồn quyền lực cho tiền/kho.
class SyncEngine {
  SyncEngine({
    required this.outbox,
    required this.store,
    required this.client,
  }) : _enabled = true;

  SyncEngine.disabled({required this.outbox, required this.store})
      : _enabled = false,
        client = null;

  static const String watermarkKey = 'smartcafe_sync_v1';

  final Outbox outbox;
  final DataStore store;
  final SupabaseClient? client;
  final bool _enabled;

  bool _running = false;
  bool _flushing = false;
  bool _pulling = false;
  Timer? _timer;
  RealtimeChannel? _channel;

  void start() {
    if (!_enabled || _running) return;
    _running = true;
    // retry loop: mỗi 15s thử push/pull (khi online). Cheap no-op khi offline.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(flush());
      unawaited(pull());
      ensureRealtime();
    });
    unawaited(flush());
    unawaited(pull());
    ensureRealtime();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Đăng ký realtime (postgres_changes) khi có session: sự thay đổi ở DB
  /// (đơn/bàn/khách/kho/voucher) kích hoạt pull ngay -> 2 app hội tụ nhanh.
  /// Gọi lại sau mỗi tick; khi chưa login thì không làm gì.
  void ensureRealtime() {
    final c = client;
    if (!_enabled || _channel != null || !online || c == null) return;
    _channel = c.channel('smartcafe-changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (_) => unawaited(pull()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'cafe_tables',
        callback: (_) => unawaited(pull()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'customers',
        callback: (_) => unawaited(pull()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ingredients',
        callback: (_) => unawaited(pull()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'vouchers',
        callback: (_) => unawaited(pull()),
      )
      ..subscribe();
  }

  bool get online => _enabled && client?.auth.currentSession != null;

  /// Replay outbox FIFO qua RPC. Bỏ op chỉ khi thành công; lỗi (offline,
  /// table_busy, ...) -> dừng, giữ op để retry.
  Future<void> flush() async {
    if (!online || _flushing) return;
    _flushing = true;
    try {
      final ops = List<OutboxOp>.from(outbox.pending);
      for (final op in ops) {
        try {
          await _replay(op);
          await outbox.remove(op.id);
        } on AuthException {
          return; // mất session -> dừng
        } on PostgrestException catch (e) {
          // lỗi nghiệp vụ vĩnh viễn (vd table_busy, order_paid) -> bỏ op,
          // để không kẹt hàng đợi mãi; UI đã có conflict banner.
          if (e.code == null || e.code!.startsWith('P')) {
            await outbox.remove(op.id);
          } else {
            return; // network/transient -> retry sau
          }
        } catch (_) {
          return; // transient -> retry sau
        }
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _replay(OutboxOp op) async {
    final c = client!;
    switch (op.type) {
      case 'place_order':
        await c.rpc('rpc_place_order', params: {
          'p_cashier_id': c.auth.currentUser!.id,
          'p_client_order_id': op.payload['orderId'],
          'p_order_type': op.payload['orderType'],
          'p_items': op.payload['items'],
          'p_table_id': op.payload['tableId'],
          'p_customer_id': op.payload['customerId'],
          'p_voucher_code': op.payload['voucherCode'],
          'p_points_used': op.payload['pointsUsed'],
          'p_points_discount': op.payload['pointsDiscount'],
          'p_note': op.payload['note'],
        });
      case 'consume_recipe':
        await c.rpc('rpc_consume_recipe',
            params: {'p_order_id': op.payload['orderId']});
      case 'pay_order':
        await c.rpc('rpc_pay_order', params: {
          'p_order_id': op.payload['orderId'],
          'p_method': op.payload['method'],
        });
      case 'cancel_order':
        await c.rpc('rpc_cancel_order', params: {
          'p_order_id': op.payload['orderId'],
          'p_reason': op.payload['reason'],
        });
      case 'move_order':
        await c.rpc('rpc_move_order', params: {
          'p_order_id': op.payload['orderId'],
          'p_new_table_id': op.payload['newTableId'],
        });
      case 'adjust_stock':
        await c.rpc('rpc_adjust_stock', params: {
          'p_ingredient_id': op.payload['ingredientId'],
          'p_type': op.payload['type'],
          'p_quantity': op.payload['quantity'],
          'p_note': op.payload['note'],
          'p_actor_id': c.auth.currentUser!.id,
        });
    }
  }

  /// Kéo dữ liệu thay đổi từ DB về (updated_at > watermark), gộp vào local.
  /// RLS chặn khi chưa login / role không đủ -> không có hại.
  Future<void> pull() async {
    if (!online || _pulling) return;
    _pulling = true;
    try {
      final c = client!;
      final prefs = await SharedPreferences.getInstance();
      final watermark = prefs.getString(watermarkKey);
      final filter = watermark == null
          ? null
          : (PostgrestFilterBuilder<List<Map<String, dynamic>>> b) =>
              b.gte('updated_at', watermark);

      await _pullCategories(c, filter);
      await _pullToppings(c, filter);
      await _pullProducts(c, filter);
      await _pullTables(c, filter);
      await _pullIngredients(c, filter);
      await _pullCustomers(c, filter);
      await _pullVouchers(c, filter);
      await _pullOrders(c, filter);

      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(watermarkKey, now);
    } catch (_) {
      // offline/RLS deny -> retry lần sau
    } finally {
      _pulling = false;
    }
  }

  Future<void> _pullCategories(
      SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'categories', filter);
    for (final r in rows) {
      final existing = store.findCategory(r['id'] as String? ?? '');
      final cat = ProductCategory(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        description: r['description'] as String? ?? '',
        icon: r['icon'] as String? ?? '☕',
        active: r['active'] as bool? ?? true,
      );
      if (existing == null) {
        store.addCategory(cat);
      } else {
        store.updateCategory(cat);
      }
    }
  }

  Future<void> _pullToppings(SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'toppings', filter);
    for (final r in rows) {
      final id = r['id'] as String;
      final topping = Topping(
        id: id,
        name: r['name'] as String? ?? '',
        price: _num(r['price']),
        available: r['available'] as bool? ?? true,
      );
      if (store.toppings.any((t) => t.id == id)) {
        store.updateTopping(topping);
      } else {
        store.addTopping(topping);
      }
    }
  }

  Future<void> _pullProducts(SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'products', filter);
    for (final r in rows) {
      final id = r['id'] as String;
      final sizes = <DrinkSize, double>{};
      final pm = r['price_by_size'];
      if (pm is Map) {
        pm.forEach((k, v) {
          sizes[_enum(DrinkSize.values, k as String?, DrinkSize.m)] = _num(v);
        });
      }
      final product = Product(
        id: id,
        name: r['name'] as String? ?? '',
        description: r['description'] as String? ?? '',
        imageUrl: r['image_url'] as String? ?? '',
        emoji: r['emoji'] as String? ?? '☕',
        categoryId: r['category_id'] as String? ?? '',
        basePrice: _num(r['base_price']),
        priceBySize: sizes.isEmpty ? null : sizes,
        availableToppingIds:
            (r['available_topping_ids'] as List?)?.cast<String>() ?? const [],
        inStock: r['in_stock'] as bool? ?? true,
        hidden: r['hidden'] as bool? ?? false,
      );
      if (store.products.any((p) => p.id == id)) {
        store.updateProduct(product);
      } else {
        store.addProduct(product);
      }
    }
  }

  Future<void> _pullTables(SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'cafe_tables', filter);
    for (final r in rows) {
      final id = r['id'] as String;
      final table = CafeTable(
        id: id,
        tableName: r['table_name'] as String? ?? id,
        capacity: _int(r['capacity']),
        status: _enum(
            TableStatus.values, r['status'] as String?, TableStatus.empty),
        currentOrderId: r['current_order_id'] as String?,
        qrCodeValue: r['qr_code_value'] as String? ?? '',
      );
      final existing = store.findTable(id);
      if (existing == null) {
        store.tables.add(table);
        store.notifyListeners();
      } else if (existing.status != table.status ||
          existing.currentOrderId != table.currentOrderId ||
          existing.tableName != table.tableName) {
        // giữ vị trí list; cập nhật field trực tiếp (CafeTable mutable)
        existing.status = table.status;
        existing.currentOrderId = table.currentOrderId;
        store.notifyListeners();
      }
    }
  }

  Future<void> _pullIngredients(
      SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'ingredients', filter);
    for (final r in rows) {
      final id = r['id'] as String;
      final ing = Ingredient(
        id: id,
        name: r['name'] as String? ?? '',
        unit: r['unit'] as String? ?? '',
        currentStock: _num(r['current_stock']),
        minStock: _num(r['min_stock']),
        costPerUnit: _num(r['cost_per_unit']),
        supplier: r['supplier'] as String? ?? '',
        expiredDate: _prs(r['expired_date'] as String?),
        active: r['active'] as bool? ?? true,
      );
      final existing = store.findIngredient(id);
      if (existing == null) {
        store.addIngredient(ing);
      } else {
        // DB là nguồn quyền lực cho kho -> ghi đè bằng object mới
        // (giữ createdAt local, cập nhật updatedAt)
        final idx = store.ingredients.indexOf(existing);
        store.ingredients[idx] = Ingredient(
          id: id,
          name: ing.name,
          unit: ing.unit,
          currentStock: ing.currentStock,
          minStock: ing.minStock,
          costPerUnit: ing.costPerUnit,
          supplier: ing.supplier,
          expiredDate: ing.expiredDate,
          active: ing.active,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now(),
        );
        store.notifyListeners();
      }
    }
  }

  Future<void> _pullCustomers(
      SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'customers', filter);
    for (final r in rows) {
      final id = r['id'] as String;
      final points = _int(r['points']);
      final customer = Customer(
        id: id,
        fullName: r['full_name'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String? ?? '',
        points: points,
        rank: _enum(CustomerRank.values, r['rank'] as String?,
            CustomerRank.fromPoints(points)),
        totalSpent: _num(r['total_spent']),
        totalOrders: _int(r['total_orders']),
        favoriteProducts:
            (r['favorite_products'] as List?)?.cast<String>() ?? const [],
      );
      final existing = store.findCustomer(id);
      if (existing == null) {
        store.addCustomer(customer);
      } else {
        // DB quyền lực cho điểm/rank/doanh số
        existing.points = points;
        existing.rank = CustomerRank.fromPoints(points);
        existing.totalSpent = customer.totalSpent;
        existing.totalOrders = customer.totalOrders;
        store.notifyListeners();
      }
    }
  }

  Future<void> _pullVouchers(SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'vouchers', filter);
    for (final r in rows) {
      final id = r['id'] as String;
      final voucher = Voucher(
        id: id,
        code: r['code'] as String? ?? '',
        name: r['name'] as String? ?? '',
        discountType: _enum(DiscountType.values, r['discount_type'] as String?,
            DiscountType.amount),
        discountValue: _num(r['discount_value']),
        minOrderValue: _num(r['min_order_value']),
        maxDiscount: _num(r['max_discount']),
        startDate: _prs(r['start_date'] as String?) ?? DateTime.now(),
        endDate: _prs(r['end_date'] as String?) ?? DateTime.now(),
        usageLimit: _int(r['usage_limit']),
        usedCount: _int(r['used_count']),
        active: r['active'] as bool? ?? true,
      );
      if (store.vouchers.any((v) => v.id == id)) {
        store.updateVoucher(voucher);
      } else {
        store.addVoucher(voucher);
      }
    }
  }

  Future<void> _pullOrders(SupabaseClient c, _WatermarkFilter? filter) async {
    final rows = await _select(c, 'orders', filter);
    if (rows.isEmpty) return;
    // lấy order_items cho các đơn vừa pull
    final orderIds = rows.map((r) => r['id'] as String).toList();
    final itemRows =
        await c.from('order_items').select().inFilter('order_id', orderIds);
    final itemsByOrder = <String, List<OrderItem>>{};
    for (final ir in itemRows) {
      final oid = ir['order_id'] as String;
      final item = OrderItem(
        id: (ir['id'] ?? '').toString(),
        productId: ir['product_id'] as String? ?? '',
        productName: ir['product_name'] as String? ?? '',
        emoji: ir['emoji'] as String? ?? '☕',
        size: _enum(DrinkSize.values, ir['size'] as String?, DrinkSize.m),
        toppingIds: (ir['topping_ids'] as List?)?.cast<String>() ?? const [],
        toppingNames:
            (ir['topping_names'] as List?)?.cast<String>() ?? const [],
        toppingsPrice: _num(ir['toppings_price']),
        sugar:
            _enum(SugarLevel.values, ir['sugar'] as String?, SugarLevel.full),
        ice: _enum(IceLevel.values, ir['ice'] as String?, IceLevel.normal),
        quantity: _int(ir['quantity']),
        unitPrice: _num(ir['unit_price']),
        note: ir['note'] as String? ?? '',
        status: ir['status'] as String? ?? 'pending',
      );
      itemsByOrder.putIfAbsent(oid, () => []).add(item);
    }

    for (final r in rows) {
      final id = r['id'] as String;
      final order = AppOrder(
        id: id,
        orderCode: r['order_code'] as String? ?? '',
        tableId: r['table_id'] as String?,
        tableName: r['table_name'] as String?,
        customerId: r['customer_id'] as String?,
        customerName: r['customer_name'] as String?,
        cashierId: r['cashier_id']?.toString() ?? '',
        cashierName: r['cashier_name'] as String? ?? '',
        orderType: _enum(
            OrderType.values, r['order_type'] as String?, OrderType.dineIn),
        items: itemsByOrder[id] ?? const [],
        subtotal: _num(r['subtotal']),
        discount: _num(r['discount']),
        voucherCode: r['voucher_code'] as String?,
        pointsUsed: _int(r['points_used']),
        pointsDiscount: _num(r['points_discount']),
        total: _num(r['total']),
        paymentMethod: r['payment_method'] == null
            ? null
            : _enum(PaymentMethod.values, r['payment_method'] as String,
                PaymentMethod.cash),
        paymentStatus: _enum(PaymentStatus.values,
            r['payment_status'] as String?, PaymentStatus.unpaid),
        orderStatus: _enum(OrderStatus.values, r['order_status'] as String?,
            OrderStatus.pending),
        note: r['note'] as String? ?? '',
        createdAt: _prs(r['created_at'] as String?) ?? DateTime.now(),
        updatedAt: _prs(r['updated_at'] as String?) ?? DateTime.now(),
        completedAt: _prs(r['completed_at'] as String?),
      );
      final i = store.iOf(id);
      if (i >= 0) {
        store.orders[i] = order; // DB là quyền lực cho đơn hàng
      } else {
        store.orders.add(order);
      }
    }
    store.notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _select(
      SupabaseClient c, String table, _WatermarkFilter? filter) async {
    var q = c.from(table).select();
    if (filter != null) q = filter(q);
    return (await q).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

typedef _WatermarkFilter = PostgrestFilterBuilder<List<Map<String, dynamic>>>
    Function(PostgrestFilterBuilder<List<Map<String, dynamic>>> b);

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
DateTime? _prs(String? v) => v == null ? null : DateTime.tryParse(v);
E _enum<E extends Enum>(List<E> all, dynamic name, E fallback) {
  if (name is String) {
    for (final e in all) {
      if (e.name == name) return e;
    }
  }
  return fallback;
}
