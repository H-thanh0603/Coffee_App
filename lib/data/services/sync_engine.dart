import 'dart:async';
import 'dart:math' show Random;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthChangeEvent,
        AuthException,
        AuthState,
        PostgrestException,
        PostgresChangeEvent,
        PostgrestFilterBuilder,
        RealtimeChannel,
        SupabaseClient;

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
  static const String orderWatermarkKey = 'smartcafe_sync_orders_v1';

  final Outbox outbox;
  final DataStore store;
  final SupabaseClient? client;
  final bool _enabled;

  bool _running = false;
  bool _flushing = false;
  bool _pulling = false;
  Timer? _timer;
  RealtimeChannel? _channel;

  // --- Exponential backoff ---
  Duration _currentInterval = const Duration(seconds: 15);
  static const Duration _baseInterval = Duration(seconds: 15);
  static const Duration _maxInterval = Duration(seconds: 120);

  // --- Per-role realtime ---
  UserRole? _role;
  UserRole? _subscribedRole;
  StreamSubscription<AuthState>? _authSub;

  void setRole(UserRole? role) {
    if (_role == role) return;
    _role = role;
    // Re-subscribe with new role
    _channel?.unsubscribe();
    _channel = null;
    _subscribedRole = null;
    ensureRealtime();
  }

  /// Lắng nghe auth state: khi login/logout -> fetch role từ app_users
  /// và cập nhật realtime subscriptions.
  void listenAuth() {
    final c = client;
    if (c == null) return;
    _authSub?.cancel();
    _authSub = c.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        final userId = data.session?.user.id;
        if (userId == null) return;
        try {
          final row = await c
              .from('app_users')
              .select('role')
              .eq('id', userId)
              .limit(1)
              .maybeSingle();
          if (row != null) {
            final roleCode = row['role'] as String?;
            if (roleCode != null) {
              final role =
                  UserRole.values.where((r) => r.name == roleCode).firstOrNull;
              if (role != null) setRole(role);
            }
          }
        } catch (_) {
          // offline/error -> keep current role
        }
      } else if (event == AuthChangeEvent.signedOut) {
        setRole(null);
      }
    });
  }

  void dispose() {
    _authSub?.cancel();
    _authSub = null;
  }

  void start() {
    if (!_enabled || _running) return;
    _running = true;
    _scheduleNext();
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

  // --- Exponential backoff timer ---

  void _scheduleNext() {
    _timer?.cancel();
    // ±20% jitter để tránh thundering herd
    final jitterMs =
        (_currentInterval.inMilliseconds * 0.2 * Random().nextDouble()).toInt();
    final delay = _currentInterval + Duration(milliseconds: jitterMs);
    _timer = Timer(delay, () {
      if (!_running) return;
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    await Future.wait([flush(), pull()]);
    ensureRealtime();
    _scheduleNext();
  }

  void _onSyncSuccess() {
    _currentInterval = _baseInterval;
  }

  void _onSyncFailure() {
    final nextMs = (_currentInterval.inMilliseconds * 2)
        .clamp(_baseInterval.inMilliseconds, _maxInterval.inMilliseconds);
    _currentInterval = Duration(milliseconds: nextMs);
  }

  // --- Per-role realtime subscriptions ---

  /// Đăng ký realtime (postgres_changes) khi có session: sự thay đổi ở DB
  /// kích hoạt pull ngay -> 2 app hội tụ nhanh.
  /// Chỉ subscribe các table liên quan đến role hiện tại.
  void ensureRealtime() {
    final c = client;
    if (!_enabled || !online || c == null) return;

    // Chưa có role -> fallback subscribe all (như cũ)
    final role = _role;
    if (role == null) {
      if (_channel != null) return;
      _subscribeAll(c);
      return;
    }

    // Đã subscribe role này rồi -> skip
    if (_channel != null && _subscribedRole == role) return;

    // Role thay đổi -> unsubscribe旧, subscribe mới
    _channel?.unsubscribe();
    _subscribedRole = role;
    _subscribeForRole(c, role);
  }

  void _subscribeAll(SupabaseClient c) {
    final tables = [
      'orders',
      'cafe_tables',
      'customers',
      'ingredients',
      'vouchers',
      'products',
      'categories',
      'toppings',
    ];
    _channel = _createChannel(c, 'smartcafe-all', tables);
  }

  void _subscribeForRole(SupabaseClient c, UserRole role) {
    final tables = _tablesForRole(role);
    _channel = _createChannel(c, 'smartcafe-${role.name}', tables);
  }

  RealtimeChannel _createChannel(
      SupabaseClient c, String name, List<String> tables) {
    final ch = c.channel(name);
    for (final table in tables) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => unawaited(pull()),
      );
    }
    return ch..subscribe();
  }

  List<String> _tablesForRole(UserRole role) => switch (role) {
        UserRole.admin => [
            'orders',
            'cafe_tables',
            'customers',
            'ingredients',
            'vouchers',
            'products',
            'categories',
            'toppings',
          ],
        UserRole.cashier => [
            'orders',
            'cafe_tables',
            'customers',
            'products',
            'categories',
            'toppings',
          ],
        UserRole.barista => [
            'orders',
            'cafe_tables',
            'ingredients',
            'products',
            'categories',
            'toppings',
          ],
        UserRole.waiter => [
            'orders',
            'cafe_tables',
            'products',
            'categories',
            'toppings',
          ],
        UserRole.customer => [
            'orders',
            'cafe_tables',
          ],
      };

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
        } catch (e) {
          if (e is PostgrestException &&
              e.code != null &&
              e.code!.startsWith('P')) {
            // lỗi nghiệp vụ vĩnh viễn (vd table_busy, order_paid) -> bỏ op,
            // để không kẹt hàng đợi mãi; UI đã có conflict banner.
            await outbox.remove(op.id);
          } else {
            return; // network/transient -> retry sau
          }
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
  /// Dùng batch mode: suppress notifyListeners + persist trong pull,
  /// gọi endBatchUpdate 1 lần ở cuối -> 1 persist duy nhất.
  Future<void> pull() async {
    if (!online || _pulling) return;
    _pulling = true;
    store.beginBatchUpdate();
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
      await _pullOrders(c);

      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(watermarkKey, now);
      _onSyncSuccess();
    } catch (_) {
      _onSyncFailure();
    } finally {
      store.endBatchUpdate();
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
      } else if (existing.status != table.status ||
          existing.currentOrderId != table.currentOrderId ||
          existing.tableName != table.tableName) {
        existing.status = table.status;
        existing.currentOrderId = table.currentOrderId;
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
        existing.points = points;
        existing.rank = CustomerRank.fromPoints(points);
        existing.totalSpent = customer.totalSpent;
        existing.totalOrders = customer.totalOrders;
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

  /// Pull orders với cursor-based pagination, LIMIT 100 per cycle.
  /// Dùng orderWatermarkKey riêng biệt để track last-seen updated_at.
  Future<void> _pullOrders(SupabaseClient c) async {
    final prefs = await SharedPreferences.getInstance();
    final orderWatermark = prefs.getString(orderWatermarkKey);

    var q = c.from('orders').select();
    if (orderWatermark != null) {
      q = q.gte('updated_at', orderWatermark);
    }
    final rows = (await q
            .order('updated_at', ascending: true)
            .limit(100))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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

    String? latestUpdatedAt;
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

      // Track cursor
      final ua = r['updated_at'] as String?;
      if (ua != null &&
          (latestUpdatedAt == null || ua.compareTo(latestUpdatedAt) > 0)) {
        latestUpdatedAt = ua;
      }
    }

    if (latestUpdatedAt != null) {
      await prefs.setString(orderWatermarkKey, latestUpdatedAt);
    }
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
