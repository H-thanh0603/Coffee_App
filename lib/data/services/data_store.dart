import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/formatters.dart';
import '../models/app_notification.dart';
import '../models/cafe_table.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/ingredient.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../models/recipe.dart';
import '../models/stock_transaction.dart';
import '../models/topping.dart';
import '../models/user.dart';
import '../models/voucher.dart';
import '../seed/seed_categories.dart';
import '../seed/seed_customers.dart';
import '../seed/seed_ingredients.dart';
import '../seed/seed_products.dart';
import '../seed/seed_recipes.dart';
import '../seed/seed_tables.dart';
import '../seed/seed_toppings.dart';
import '../seed/seed_users.dart';
import '../seed/seed_vouchers.dart';
import 'persistence.dart';

/// In-memory data store - đóng vai trò mô phỏng Firestore.
/// Tất cả các operation đều là realtime nhờ ChangeNotifier.
class DataStore extends ChangeNotifier {
  final List<AppUser> users = [];
  final List<ProductCategory> categories = [];
  final List<Topping> toppings = [];
  final List<Product> products = [];
  final List<CafeTable> tables = [];
  final List<Customer> customers = [];
  final List<Ingredient> ingredients = [];
  final List<Recipe> recipes = [];
  final List<Voucher> vouchers = [];
  final List<AppOrder> orders = [];
  final List<StockTransaction> stockTxs = [];
  final List<AppNotification> notifications = [];

  static const String storageKey = 'smartcafe_data_v1';
  SharedPreferences? _prefs;

  /// Bộ đếm dùng để sinh mã đơn — cần lưu cùng state để không trùng mã.
  int orderSeq = 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getString(storageKey);
    // Có dữ liệu đã lưu -> khôi phục thay vì seed lại
    if (raw != null && raw.isNotEmpty && StoreCodec.decode(this, raw)) {
      _checkVoucherAlerts();
      _checkSlowOrderAlerts();
      return;
    }
    _seed();
    _checkVoucherAlerts();
    _checkSlowOrderAlerts();
    await _persist();
  }

  /// Seed dữ liệu mẫu khi chưa có dữ liệu lưu trước đó.
  void _seed() {
    users.addAll(seedUsers());
    categories.addAll(seedCategories());
    toppings.addAll(seedToppings());
    products.addAll(seedProducts());
    tables.addAll(seedTables());
    customers.addAll(seedCustomers());
    ingredients.addAll(seedIngredients());
    recipes.addAll(seedRecipes());
    vouchers.addAll(seedVouchers());
    _seedSampleOrders();
  }

  /// Lưu toàn bộ state xuống SharedPreferences.
  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(storageKey, StoreCodec.encode(this));
    } catch (_) {
      // Persistence là phụ trợ - fail im lặng không làm hỏng app
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    unawaited(_persist());
  }

  // ===== USER =====
  AppUser? findUserByEmail(String email) {
    try {
      return users.firstWhere((u) => u.email == email);
    } catch (_) {
      return null;
    }
  }

  void addUser(AppUser u) {
    users.add(u);
    notifyListeners();
  }

  void updateUser(AppUser u) {
    final i = users.indexWhere((e) => e.id == u.id);
    if (i >= 0) users[i] = u;
    notifyListeners();
  }

  void removeUser(String id) {
    users.removeWhere((u) => u.id == id);
    notifyListeners();
  }

  // ===== CATEGORY =====
  ProductCategory? findCategory(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  void addCategory(ProductCategory c) {
    categories.add(c);
    notifyListeners();
  }

  void updateCategory(ProductCategory c) {
    final i = categories.indexWhere((e) => e.id == c.id);
    if (i >= 0) categories[i] = c;
    notifyListeners();
  }

  void removeCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // ===== PRODUCT =====
  void addProduct(Product p) {
    products.add(p);
    notifyListeners();
  }

  void updateProduct(Product p) {
    final i = products.indexWhere((e) => e.id == p.id);
    if (i >= 0) products[i] = p;
    notifyListeners();
  }

  void removeProduct(String id) {
    products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ===== RECIPE =====
  Recipe? findRecipe(String productId, DrinkSize size) {
    for (final r in recipes) {
      if (r.productId == productId && r.size == size) return r;
    }
    return null;
  }

  /// Recipe cho món + size, fallback về recipe đầu tiên của món nếu size đó
  /// chưa có (mặc định size M). Dùng chung cho trừ kho và tính giá vốn.
  Recipe? _recipeFor(String productId, DrinkSize size) {
    return findRecipe(productId, size) ??
        recipes.cast<Recipe?>().firstWhere(
              (r) => r?.productId == productId,
              orElse: () => null,
            );
  }

  void addRecipe(Recipe r) {
    recipes.add(r);
    notifyListeners();
  }

  void updateRecipe(Recipe r) {
    final i = recipes.indexWhere((e) => e.id == r.id);
    if (i >= 0) recipes[i] = r;
    notifyListeners();
  }

  void removeRecipe(String id) {
    recipes.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // ===== TOPPING =====
  Topping? findTopping(String id) {
    for (final t in toppings) {
      if (t.id == id) return t;
    }
    return null;
  }

  void addTopping(Topping t) {
    toppings.add(t);
    notifyListeners();
  }

  void updateTopping(Topping t) {
    final i = toppings.indexWhere((e) => e.id == t.id);
    if (i >= 0) toppings[i] = t;
    notifyListeners();
  }

  void removeTopping(String id) {
    toppings.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ===== TABLE =====
  CafeTable? findTable(String id) {
    for (final t in tables) {
      if (t.id == id) return t;
    }
    return null;
  }

  void setTableStatus(String id, TableStatus status, {String? orderId}) {
    final t = findTable(id);
    if (t != null) {
      t.status = status;
      t.currentOrderId = orderId;
      if (status == TableStatus.waiting) {
        _addNotification(
          title: 'Bàn chờ thanh toán',
          message: t.tableName + ' đang chờ thanh toán',
          type: 'table_waiting',
          role: UserRole.cashier,
        );
      }
      notifyListeners();
    }
  }

  // ===== CUSTOMER =====
  Customer? findCustomer(String id) {
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  Customer? findCustomerByPhone(String phone) {
    try {
      return customers.firstWhere((c) => c.phone == phone);
    } catch (_) {
      return null;
    }
  }

  void addCustomer(Customer c) {
    customers.add(c);
    notifyListeners();
  }

  void updateCustomer(Customer c) {
    final i = customers.indexWhere((e) => e.id == c.id);
    if (i >= 0) customers[i] = c;
    notifyListeners();
  }

  // ===== INGREDIENT =====
  Ingredient? findIngredient(String id) {
    for (final i in ingredients) {
      if (i.id == id) return i;
    }
    return null;
  }

  void addIngredient(Ingredient i) {
    ingredients.add(i);
    notifyListeners();
  }

  void updateIngredient(Ingredient i) {
    final idx = ingredients.indexWhere((e) => e.id == i.id);
    if (idx >= 0) ingredients[idx] = i;
    notifyListeners();
  }

  void stockIn(String ingId, double qty, String createdBy, {String note = ''}) {
    final ing = findIngredient(ingId);
    if (ing == null) return;
    ing.currentStock += qty;
    ing.updatedAt = DateTime.now();
    stockTxs.add(StockTransaction(
      id: const Uuid().v4(),
      ingredientId: ingId,
      ingredientName: ing.name,
      type: StockTxType.inbound,
      quantity: qty,
      unit: ing.unit,
      note: note,
      createdBy: createdBy,
    ));
    notifyListeners();
  }

  void stockOut(String ingId, double qty, String createdBy,
      {String note = ''}) {
    final ing = findIngredient(ingId);
    if (ing == null) return;
    ing.currentStock = (ing.currentStock - qty).clamp(0, double.infinity);
    ing.updatedAt = DateTime.now();
    stockTxs.add(StockTransaction(
      id: const Uuid().v4(),
      ingredientId: ingId,
      ingredientName: ing.name,
      type: StockTxType.outbound,
      quantity: qty,
      unit: ing.unit,
      note: note,
      createdBy: createdBy,
    ));
    notifyListeners();
  }

  /// Trả về danh sách nguyên liệu không đủ để làm các [items].
  /// Rỗng = đủ nguyên liệu. Mỗi entry: (ingredient, thiếu bao nhiêu).
  List<MapEntry<Ingredient, double>> missingIngredients(List<OrderItem> items) {
    final need = <String, double>{};
    for (final item in items) {
      final r = _recipeFor(item.productId, item.size);
      if (r == null) continue;
      for (final ri in r.items) {
        need[ri.ingredientId] =
            (need[ri.ingredientId] ?? 0) + ri.quantity * item.quantity;
      }
    }
    return need.entries
        .map((e) {
          final ing = findIngredient(e.key);
          if (ing == null || ing.currentStock >= e.value) return null;
          return MapEntry(ing, e.value - ing.currentStock);
        })
        .whereType<MapEntry<Ingredient, double>>()
        .toList();
  }

  /// Trừ kho theo công thức khi đơn được xác nhận pha chế
  void consumeRecipe(AppOrder order) {
    for (final item in order.items) {
      final r = _recipeFor(item.productId, item.size);
      if (r == null) continue;
      for (final ri in r.items) {
        final ing = findIngredient(ri.ingredientId);
        if (ing == null) continue;
        final used = ri.quantity * item.quantity;
        ing.currentStock = (ing.currentStock - used).clamp(0, double.infinity);
        ing.updatedAt = DateTime.now();
        stockTxs.add(StockTransaction(
          id: const Uuid().v4(),
          ingredientId: ing.id,
          ingredientName: ing.name,
          type: StockTxType.consumed,
          quantity: used,
          unit: ing.unit,
          note: 'Đơn ' + order.orderCode,
          createdBy: order.cashierName,
        ));
      }
    }
    _checkLowStockAlerts();
    final missing = missingIngredients(order.items);
    if (missing.isNotEmpty) {
      _addNotification(
        title: 'Thiếu nguyên liệu',
        message: missing.map((e) => e.key.name).take(3).join(', '),
        type: 'stock_shortage',
        role: UserRole.admin,
      );
    }
    notifyListeners();
  }

  // ===== VOUCHER =====
  Voucher? findVoucherByCode(String code) {
    try {
      return vouchers
          .firstWhere((v) => v.code.toUpperCase() == code.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  void addVoucher(Voucher v) {
    vouchers.add(v);
    _checkVoucherAlerts();
    notifyListeners();
  }

  void updateVoucher(Voucher v) {
    final i = vouchers.indexWhere((e) => e.id == v.id);
    if (i >= 0) vouchers[i] = v;
    _checkVoucherAlerts();
    notifyListeners();
  }

  void removeVoucher(String id) {
    vouchers.removeWhere((v) => v.id == id);
    notifyListeners();
  }

  // ===== ORDER =====
  AppOrder createOrder({
    required AppUser cashier,
    required List<OrderItem> items,
    required OrderType orderType,
    String? tableId,
    String? customerId,
    Voucher? voucher,
    int pointsUsed = 0,
    double pointsDiscount = 0,
    String note = '',
  }) {
    orderSeq += 1;
    final code = Fmt.orderCode(orderSeq);
    final tbl = tableId != null ? findTable(tableId) : null;
    final cust = customerId != null ? findCustomer(customerId) : null;
    // Bàn đang có đơn CHƯA THU TIỀN thì không cho tạo đơn mới (tránh đơn bị treo).
    if (tbl != null && tbl.currentOrderId != null) {
      final active = orders
          .cast<AppOrder?>()
          .firstWhere((o) => o?.id == tbl.currentOrderId, orElse: () => null);
      if (active != null && active.paymentStatus != PaymentStatus.paid) {
        throw StateError(
            'Bàn ' + tbl.tableName + ' đang có đơn chưa thanh toán');
      }
    }
    final subtotal = items.fold<double>(0, (s, e) => s + e.totalPrice);
    final discount = (voucher != null && voucher.isAvailable)
        ? voucher.calcDiscount(subtotal)
        : 0.0;
    final total = (subtotal - discount - pointsDiscount)
        .clamp(0.0, double.infinity)
        .toDouble();

    final order = AppOrder(
      id: const Uuid().v4(),
      orderCode: code,
      tableId: tableId,
      tableName: tbl?.tableName,
      customerId: customerId,
      customerName: cust?.fullName,
      cashierId: cashier.id,
      cashierName: cashier.fullName,
      orderType: orderType,
      items: items,
      subtotal: subtotal,
      discount: discount,
      voucherCode: voucher?.code,
      pointsUsed: pointsUsed,
      pointsDiscount: pointsDiscount,
      total: total,
      note: note,
    );
    orders.add(order);

    if (tbl != null) {
      tbl.status = TableStatus.serving;
      tbl.currentOrderId = order.id;
    }
    if (voucher != null && voucher.isAvailable) {
      voucher.usedCount += 1;
    }

    _addNotification(
      title: 'Đơn mới #' + code,
      message: (tbl?.tableName ?? 'Mang đi') +
          ' • ' +
          items.length.toString() +
          ' món',
      type: 'order_new',
      role: UserRole.barista,
    );
    notifyListeners();
    return order;
  }

  void updateOrderStatus(String orderId, OrderStatus status) {
    final i = orders.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = orders[i];
    if (o.orderStatus == status) {
      return; // idempotent - chống bấm đúp trừ kho 2 lần
    }
    o.orderStatus = status;
    o.updatedAt = DateTime.now();
    if (status == OrderStatus.preparing) {
      consumeRecipe(o);
    }
    _checkSlowOrderAlerts();
    notifyListeners();
  }

  void payOrder(String orderId, PaymentMethod method) {
    final i = orders.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = orders[i];
    if (o.paymentStatus == PaymentStatus.paid) return; // chống thanh toán 2 lần
    final updated = o.copyWith(
      paymentStatus: PaymentStatus.paid,
      paymentMethod: method,
      orderStatus: o.orderStatus == OrderStatus.pending
          ? OrderStatus.confirmed
          : o.orderStatus,
      completedAt: DateTime.now(), // thời điểm thu tiền, cố định cho doanh thu
    );
    orders[i] = updated;
    if (updated.tableId != null) {
      final tbl = findTable(updated.tableId!);
      if (tbl != null) {
        tbl.status = TableStatus.needsClean;
        tbl.currentOrderId = null;
      }
    }
    if (updated.customerId != null) {
      final c = findCustomer(updated.customerId!);
      if (c != null) {
        final earned = (updated.total / 10000).floor();
        // cộng điểm mua + trừ điểm đã dùng để giảm giá
        c.addPoints(earned - updated.pointsUsed);
        c.addOrder(updated.total);
      }
    }
    notifyListeners();
  }

  /// Chuyển order (đơn đang phục vụ) sang bàn khác.
  void moveOrderToTable(String orderId, String newTableId) {
    final i = orders.indexWhere((o) => o.id == orderId);
    final newT = findTable(newTableId);
    if (i < 0 || newT == null) return;
    final o = orders[i];
    final oldT = o.tableId != null ? findTable(o.tableId!) : null;
    if (oldT != null) {
      oldT.status = TableStatus.empty;
      oldT.currentOrderId = null;
    }
    orders[i] = o.copyWith(tableId: newT.id, tableName: newT.tableName);
    newT.status = TableStatus.serving;
    newT.currentOrderId = orderId;
    _addNotification(
      title: 'Bàn ' + (o.tableName ?? '') + ' → ' + newT.tableName,
      message: 'Đơn ' + o.orderCode + ' đã chuyển bàn',
      type: 'table_move',
      role: UserRole.waiter,
    );
    notifyListeners();
  }

  /// Gộp 2 bàn đang phục vụ: gộp toàn bộ món vào bàn đích, bàn nguồn về trống.
  void mergeTables(String fromTableId, String toTableId) {
    if (fromTableId == toTableId) return;
    final from = findTable(fromTableId);
    final to = findTable(toTableId);
    if (from == null || to == null) return;
    AppOrder? findOrder(String? orderId) {
      if (orderId == null) return null;
      try {
        return orders.firstWhere((o) => o.id == orderId);
      } catch (_) {
        return null;
      }
    }

    final fromOrder = findOrder(from.currentOrderId);
    final toOrder = findOrder(to.currentOrderId);
    if (fromOrder == null || toOrder == null) return;

    final mergedItems = [...toOrder.items, ...fromOrder.items];
    final subtotal = toOrder.subtotal + fromOrder.subtotal;
    final discount = toOrder.discount + fromOrder.discount;
    final total = (subtotal - discount).clamp(0.0, double.infinity).toDouble();

    orderSeq += 1;
    final merged = AppOrder(
      id: const Uuid().v4(),
      orderCode: Fmt.orderCode(orderSeq),
      tableId: to.id,
      tableName: to.tableName,
      customerId: toOrder.customerId,
      customerName: toOrder.customerName,
      cashierId: toOrder.cashierId,
      cashierName: toOrder.cashierName,
      orderType: toOrder.orderType,
      items: mergedItems,
      subtotal: subtotal,
      discount: discount,
      voucherCode: toOrder.voucherCode,
      total: total,
      note: (toOrder.note.isNotEmpty ? toOrder.note + ' ' : '') +
          fromOrder.note.trim(),
    );
    orders.add(merged);

    // Đánh dấu 2 đơn gốc đã hủy (gộp bàn), bàn nguồn về trống
    orders[iOf(fromOrder.id)] =
        fromOrder.copyWith(orderStatus: OrderStatus.cancelled);
    orders[iOf(toOrder.id)] =
        toOrder.copyWith(orderStatus: OrderStatus.cancelled);
    from.status = TableStatus.empty;
    from.currentOrderId = null;
    to.status = TableStatus.serving;
    to.currentOrderId = merged.id;
    _addNotification(
      title: 'Gộp bàn',
      message: to.tableName + ' tổng ' + merged.itemCount.toString() + ' món',
      type: 'table_merge',
      role: UserRole.waiter,
    );
    notifyListeners();
  }

  int iOf(String orderId) {
    for (var i = 0; i < orders.length; i++) {
      if (orders[i].id == orderId) return i;
    }
    return -1;
  }

  void cancelOrder(String orderId, {String? reason}) {
    final i = orders.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = orders[i];
    if (o.paymentStatus == PaymentStatus.paid) {
      return; // đã thu tiền thì không hủy
    }
    orders[i] = o.copyWith(orderStatus: OrderStatus.cancelled);
    if (o.tableId != null) {
      final tbl = findTable(o.tableId!);
      if (tbl != null) {
        tbl.status = TableStatus.empty;
        tbl.currentOrderId = null;
      }
    }
    notifyListeners();
  }

  // ===== NOTIFICATIONS =====
  void _addNotification({
    required String title,
    required String message,
    String type = 'info',
    UserRole? role,
  }) {
    notifications.insert(
      0,
      AppNotification(
        id: const Uuid().v4(),
        title: title,
        message: message,
        type: type,
        targetRole: role,
      ),
    );
  }

  void markNotificationRead(String id) {
    final i = notifications.indexWhere((n) => n.id == id);
    if (i >= 0) notifications[i].isRead = true;
    notifyListeners();
  }

  List<AppNotification> notificationsForRole(UserRole role) {
    return notifications
        .where((n) => n.targetRole == null || n.targetRole == role)
        .toList();
  }

  void _checkLowStockAlerts() {
    for (final ing in ingredients) {
      if (ing.isLow) {
        final exists = notifications.any((n) =>
            n.type == 'low_stock' && n.message.contains(ing.name) && !n.isRead);
        if (!exists) {
          _addNotification(
            title: 'Nguyên liệu sắp hết',
            message: ing.name +
                ' chỉ còn ' +
                ing.currentStock.toStringAsFixed(0) +
                ' ' +
                ing.unit,
            type: 'low_stock',
            role: UserRole.admin,
          );
        }
      }
    }
  }

  /// Cảnh báo đơn quá 10 phút ở pending/preparing chưa hoàn thành.
  void _checkSlowOrderAlerts() {
    for (final o in orders.where((o) =>
        (o.orderStatus == OrderStatus.pending ||
            o.orderStatus == OrderStatus.confirmed ||
            o.orderStatus == OrderStatus.preparing) &&
        o.age.inMinutes > 10)) {
      final exists = notifications.any(
          (n) => n.type == 'slow_order' && n.message.contains(o.orderCode));
      if (!exists) {
        _addNotification(
          title: 'Đơn pha chế quá lâu',
          message: o.orderCode +
              ' quá ' +
              o.age.inMinutes.toString() +
              ' phút chưa hoàn thành',
          type: 'slow_order',
          role: UserRole.barista,
        );
      }
    }
  }

  /// Cảnh báo voucher sắp hết hạn (còn <= 3 ngày).
  void _checkVoucherAlerts() {
    final now = DateTime.now();
    for (final v in vouchers) {
      if (v.active && !v.isExpired && v.endDate.difference(now).inDays <= 3) {
        final exists = notifications.any((n) =>
            n.type == 'voucher_expiring' &&
            n.message.contains(v.code) &&
            !n.isRead);
        if (!exists) {
          _addNotification(
            title: 'Voucher sắp hết hạn',
            message: v.code + ' hết hạn ' + Fmt.date(v.endDate),
            type: 'voucher_expiring',
            role: UserRole.admin,
          );
        }
      }
    }
  }

  // ===== STATS =====
  List<AppOrder> get paidOrders =>
      orders.where((o) => o.paymentStatus == PaymentStatus.paid).toList();

  double revenueOnDate(DateTime date) =>
      ordersOnDate(date).fold<double>(0, (s, o) => s + o.total);

  List<AppOrder> ordersOnDate(DateTime date) {
    return paidOrders.where((o) {
      final t = o.paidAt;
      return t.year == date.year && t.month == date.month && t.day == date.day;
    }).toList();
  }

  double get revenueToday => revenueOnDate(DateTime.now());
  double get revenueYesterday =>
      revenueOnDate(DateTime.now().subtract(const Duration(days: 1)));

  int get ordersTodayCount => ordersOnDate(DateTime.now()).length;

  /// Doanh thu 7 ngày gần nhất - trả về list (label, value)
  List<MapEntry<String, double>> revenueLast7Days() {
    final result = <MapEntry<String, double>>[];
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final d =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      result.add(MapEntry(Fmt.shortDate(d), revenueOnDate(d)));
    }
    return result;
  }

  /// Doanh thu N ngày gần nhất (dùng cho báo cáo filter 1/7/30 ngày).
  List<MapEntry<String, double>> revenueLastNDays(int n) {
    final result = <MapEntry<String, double>>[];
    final now = DateTime.now();
    for (var i = n - 1; i >= 0; i--) {
      final d =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      result.add(MapEntry(Fmt.shortDate(d), revenueOnDate(d)));
    }
    return result;
  }

  /// Giá vốn của 1 order (tiền nguyên liệu theo công thức + topping).
  double _costOfOrder(AppOrder o) {
    double cost = 0;
    for (final it in o.items) {
      final r = _recipeFor(it.productId, it.size);
      if (r != null) {
        for (final ri in r.items) {
          final ing = findIngredient(ri.ingredientId);
          cost += (ing?.costPerUnit ?? 0) * ri.quantity * it.quantity;
        }
      }
      // Topping không nằm trong công thức -> tính giá vốn topping = 60% giá bán
      cost += it.toppingsPrice * it.quantity * 0.6;
    }
    return cost;
  }

  /// Lợi nhuận ước tính: doanh thu thực thu - giá vốn (theo paidAt).
  double profitInRange(int days) {
    final since = DateTime.now().subtract(Duration(days: days));
    double revenue = 0, cost = 0;
    for (final o in paidOrders.where((o) => o.paidAt.isAfter(since))) {
      revenue += o.total; // tổng đã trừ voucher/điểm
      cost += _costOfOrder(o);
    }
    return revenue - cost;
  }

  /// Top sản phẩm bán chạy theo số ly trong 7 ngày
  List<MapEntry<Product, int>> topProducts({int days = 7, int limit = 5}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final o in paidOrders.where((o) => o.paidAt.isAfter(since))) {
      for (final i in o.items) {
        counts[i.productId] = (counts[i.productId] ?? 0) + i.quantity;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <MapEntry<Product, int>>[];
    for (final e in sorted.take(limit)) {
      final p = products
          .cast<Product?>()
          .firstWhere((x) => x?.id == e.key, orElse: () => null);
      if (p != null) result.add(MapEntry(p, e.value));
    }
    return result;
  }

  /// Sản phẩm bán chậm trong tuần — chỉ tính món ĐÃ bán (count > 0),
  /// loại món không bán ly nào (không phải "bán chậm", chỉ là không bán).
  List<MapEntry<Product, int>> slowProducts({int days = 7, int threshold = 5}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final o in paidOrders.where((o) => o.paidAt.isAfter(since))) {
      for (final i in o.items) {
        counts[i.productId] = (counts[i.productId] ?? 0) + i.quantity;
      }
    }
    final result = <MapEntry<Product, int>>[];
    counts.forEach((pid, count) {
      if (count > 0 && count < threshold) {
        final p = products
            .cast<Product?>()
            .firstWhere((x) => x?.id == pid, orElse: () => null);
        if (p != null && !p.hidden) result.add(MapEntry(p, count));
      }
    });
    result.sort((a, b) => a.value.compareTo(b.value));
    return result;
  }

  /// Gợi ý nhập hàng dựa trên tốc độ tiêu thụ
  List<MapEntry<Ingredient, double>> suggestRestock() {
    final result = <MapEntry<Ingredient, double>>[];
    final since = DateTime.now().subtract(const Duration(days: 7));
    for (final ing in ingredients) {
      final consumed = stockTxs
          .where((t) =>
              t.ingredientId == ing.id &&
              t.type == StockTxType.consumed &&
              t.createdAt.isAfter(since))
          .fold<double>(0, (s, e) => s + e.quantity);
      final dailyRate = consumed / 7;
      final daysLeft = dailyRate > 0 ? ing.currentStock / dailyRate : 999;
      if (ing.isLow || daysLeft <= 5) {
        // gợi ý nhập đủ dùng 14 ngày
        final suggested =
            (dailyRate * 14 - ing.currentStock).clamp(0, double.infinity);
        result.add(MapEntry(ing, suggested.toDouble()));
      }
    }
    result.sort((a, b) => a.key.currentStock.compareTo(b.key.currentStock));
    return result;
  }

  // ===== SAMPLE ORDERS for demo =====
  void _seedSampleOrders() {
    final cashier = users.firstWhere((u) => u.role == UserRole.cashier);
    final now = DateTime.now();
    final productPicks = [
      'p-tra-dao',
      'p-trasua-truyenthong',
      'p-caphe-sua',
      'p-bac-xiu',
      'p-cappuccino',
      'p-trasua-matcha',
      'p-tra-vai',
      'p-tra-chanh',
      'p-trasua-chocolate',
      'p-soda-vietquat',
      'p-banh-tiramisu',
      'p-matcha-dax',
    ];

    int seq = 0;
    for (var dayBack = 6; dayBack >= 0; dayBack--) {
      final ordersInDay = 6 + (dayBack == 0 ? 4 : (6 - dayBack));
      for (var i = 0; i < ordersInDay; i++) {
        seq++;
        final dt = now.subtract(Duration(
          days: dayBack,
          hours: 12 - (i % 8),
          minutes: i * 7,
        ));
        final pid = productPicks[(seq + i) % productPicks.length];
        final p = products.firstWhere((x) => x.id == pid);
        final size = [DrinkSize.s, DrinkSize.m, DrinkSize.l][(i + dayBack) % 3];
        final qty = 1 + (i % 3);
        final item = OrderItem(
          id: const Uuid().v4(),
          productId: p.id,
          productName: p.name,
          emoji: p.emoji,
          size: size,
          unitPrice: p.priceFor(size),
          quantity: qty,
          status: 'served',
        );
        final subtotal = item.totalPrice;
        final cust = customers[(i + dayBack) % customers.length];
        final order = AppOrder(
          id: const Uuid().v4(),
          orderCode: Fmt.orderCode(seq + 100),
          cashierId: cashier.id,
          cashierName: cashier.fullName,
          customerId: cust.id,
          customerName: cust.fullName,
          orderType: i % 4 == 0 ? OrderType.takeaway : OrderType.dineIn,
          tableId: i % 4 == 0 ? null : tables[i % tables.length].id,
          tableName: i % 4 == 0 ? null : tables[i % tables.length].tableName,
          items: [item],
          subtotal: subtotal,
          discount: 0,
          total: subtotal,
          paymentMethod: PaymentMethod.cash,
          paymentStatus: PaymentStatus.paid,
          orderStatus: OrderStatus.paid,
          createdAt: dt,
          updatedAt: dt,
          completedAt: dt.add(const Duration(minutes: 8)),
        );
        orders.add(order);
        cust.addPoints((order.total / 10000).floor());
        cust.addOrder(order.total);
      }
    }
    orderSeq = seq + 100;
  }
}
