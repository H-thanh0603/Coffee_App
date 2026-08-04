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
      return;
    }
    _seed();
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

  void stockOut(String ingId, double qty, String createdBy, {String note = ''}) {
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

  /// Trừ kho theo công thức khi đơn được xác nhận pha chế
  void consumeRecipe(AppOrder order) {
    for (final item in order.items) {
      final recipe = recipes.cast<Recipe?>().firstWhere(
            (r) => r?.productId == item.productId && r?.size == item.size,
            orElse: () => null,
          );
      // fallback: tìm recipe size M nếu size khác không có
      final r = recipe ??
          recipes.cast<Recipe?>().firstWhere(
                (r) => r?.productId == item.productId,
                orElse: () => null,
              );
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
    notifyListeners();
  }

  // ===== VOUCHER =====
  Voucher? findVoucherByCode(String code) {
    try {
      return vouchers.firstWhere((v) => v.code.toUpperCase() == code.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  void addVoucher(Voucher v) {
    vouchers.add(v);
    notifyListeners();
  }

  void updateVoucher(Voucher v) {
    final i = vouchers.indexWhere((e) => e.id == v.id);
    if (i >= 0) vouchers[i] = v;
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
    String note = '',
  }) {
    orderSeq += 1;
    final code = Fmt.orderCode(orderSeq);
    final tbl = tableId != null ? findTable(tableId) : null;
    final cust = customerId != null ? findCustomer(customerId) : null;
    final subtotal = items.fold<double>(0, (s, e) => s + e.totalPrice);
    final discount = voucher?.calcDiscount(subtotal) ?? 0;
    final total = subtotal - discount;

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
      total: total,
      note: note,
    );
    orders.add(order);

    if (tbl != null) {
      tbl.status = TableStatus.serving;
      tbl.currentOrderId = order.id;
    }
    if (voucher != null) {
      voucher.usedCount += 1;
    }

    _addNotification(
      title: 'Đơn mới #' + code,
      message: (tbl?.tableName ?? 'Mang đi') + ' • ' + items.length.toString() + ' món',
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
    o.orderStatus = status;
    o.updatedAt = DateTime.now();
    if (status == OrderStatus.preparing) {
      consumeRecipe(o);
    }
    if (status == OrderStatus.ready || status == OrderStatus.served) {
      o.completedAt ??= DateTime.now();
    }
    notifyListeners();
  }

  void payOrder(String orderId, PaymentMethod method) {
    final i = orders.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = orders[i];
    final updated = o.copyWith(
      paymentStatus: PaymentStatus.paid,
      paymentMethod: method,
      orderStatus: o.orderStatus == OrderStatus.pending
          ? OrderStatus.confirmed
          : o.orderStatus,
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
        final pts = (updated.total / 10000).floor();
        c.addPoints(pts);
        c.addOrder(updated.total);
      }
    }
    notifyListeners();
  }

  void cancelOrder(String orderId, {String? reason}) {
    final i = orders.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = orders[i];
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
    return notifications.where((n) => n.targetRole == null || n.targetRole == role).toList();
  }

  void _checkLowStockAlerts() {
    for (final ing in ingredients) {
      if (ing.isLow) {
        final exists = notifications.any((n) =>
            n.type == 'low_stock' && n.message.contains(ing.name) && !n.isRead);
        if (!exists) {
          _addNotification(
            title: 'Nguyên liệu sắp hết',
            message: ing.name + ' chỉ còn ' + ing.currentStock.toStringAsFixed(0) + ' ' + ing.unit,
            type: 'low_stock',
            role: UserRole.admin,
          );
        }
      }
    }
  }

  // ===== STATS =====
  List<AppOrder> get paidOrders =>
      orders.where((o) => o.paymentStatus == PaymentStatus.paid).toList();

  List<AppOrder> ordersOnDate(DateTime date) {
    return paidOrders.where((o) {
      return o.createdAt.year == date.year &&
          o.createdAt.month == date.month &&
          o.createdAt.day == date.day;
    }).toList();
  }

  double revenueOnDate(DateTime date) =>
      ordersOnDate(date).fold<double>(0, (s, o) => s + o.total);

  double get revenueToday => revenueOnDate(DateTime.now());
  double get revenueYesterday =>
      revenueOnDate(DateTime.now().subtract(const Duration(days: 1)));

  int get ordersTodayCount => ordersOnDate(DateTime.now()).length;

  /// Doanh thu 7 ngày gần nhất - trả về list (label, value)
  List<MapEntry<String, double>> revenueLast7Days() {
    final result = <MapEntry<String, double>>[];
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      result.add(MapEntry(Fmt.shortDate(d), revenueOnDate(d)));
    }
    return result;
  }

  /// Top sản phẩm bán chạy theo số ly trong 7 ngày
  List<MapEntry<Product, int>> topProducts({int days = 7, int limit = 5}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final o in paidOrders.where((o) => o.createdAt.isAfter(since))) {
      for (final i in o.items) {
        counts[i.productId] = (counts[i.productId] ?? 0) + i.quantity;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <MapEntry<Product, int>>[];
    for (final e in sorted.take(limit)) {
      final p = products.cast<Product?>()
          .firstWhere((x) => x?.id == e.key, orElse: () => null);
      if (p != null) result.add(MapEntry(p, e.value));
    }
    return result;
  }

  /// Sản phẩm bán chậm trong tuần
  List<MapEntry<Product, int>> slowProducts({int days = 7, int threshold = 5}) {
    final since = DateTime.now().subtract(Duration(days: days));
    final counts = <String, int>{};
    for (final p in products) {
      counts[p.id] = 0;
    }
    for (final o in paidOrders.where((o) => o.createdAt.isAfter(since))) {
      for (final i in o.items) {
        counts[i.productId] = (counts[i.productId] ?? 0) + i.quantity;
      }
    }
    final result = <MapEntry<Product, int>>[];
    counts.forEach((pid, count) {
      if (count < threshold) {
        final p = products.cast<Product?>()
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
        final suggested = (dailyRate * 14 - ing.currentStock).clamp(0, double.infinity);
        result.add(MapEntry(ing, suggested.toDouble()));
      }
    }
    result.sort((a, b) =>
        a.key.currentStock.compareTo(b.key.currentStock));
    return result;
  }

  // ===== SAMPLE ORDERS for demo =====
  void _seedSampleOrders() {
    final cashier = users.firstWhere((u) => u.role == UserRole.cashier);
    final now = DateTime.now();
    final productPicks = [
      'p-tra-dao', 'p-trasua-truyenthong', 'p-caphe-sua', 'p-bac-xiu',
      'p-cappuccino', 'p-trasua-matcha', 'p-tra-vai', 'p-tra-chanh',
      'p-trasua-chocolate', 'p-soda-vietquat', 'p-banh-tiramisu', 'p-matcha-dax',
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
