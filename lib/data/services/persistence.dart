import 'dart:convert';

import '../../core/constants/enums.dart';
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
import 'data_store.dart';

/// Serialize/deserialize toàn bộ DataStore ra JSON string,
/// dùng để lưu vào SharedPreferences (persistence tối thiểu khi refresh/đóng app).
/// Không sửa các file model — đọc trực tiếp field public.
class StoreCodec {
  static const int _version = 1;

  static String encode(DataStore s) {
    return jsonEncode({
      'v': _version,
      'orderSeq': s.orderSeq,
      'users': s.users.map(userToJson).toList(),
      'categories': s.categories.map(categoryToJson).toList(),
      'toppings': s.toppings.map(toppingToJson).toList(),
      'products': s.products.map(productToJson).toList(),
      'tables': s.tables.map(tableToJson).toList(),
      'customers': s.customers.map(customerToJson).toList(),
      'ingredients': s.ingredients.map(ingredientToJson).toList(),
      'recipes': s.recipes.map(recipeToJson).toList(),
      'vouchers': s.vouchers.map(voucherToJson).toList(),
      'orders': s.orders.map(orderToJson).toList(),
      'stockTxs': s.stockTxs.map(stockTxToJson).toList(),
      'notifications': s.notifications.map(notificationToJson).toList(),
    });
  }

  static bool decode(DataStore s, String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return false;
      s.orderSeq = (m['orderSeq'] as num?)?.toInt() ?? 0;
      s.users
        ..clear()
        ..addAll(_listOf(m['users']).map(userFromJson));
      s.categories
        ..clear()
        ..addAll(_listOf(m['categories']).map(categoryFromJson));
      s.toppings
        ..clear()
        ..addAll(_listOf(m['toppings']).map(toppingFromJson));
      s.products
        ..clear()
        ..addAll(_listOf(m['products']).map(productFromJson));
      s.tables
        ..clear()
        ..addAll(_listOf(m['tables']).map(tableFromJson));
      s.customers
        ..clear()
        ..addAll(_listOf(m['customers']).map(customerFromJson));
      s.ingredients
        ..clear()
        ..addAll(_listOf(m['ingredients']).map(ingredientFromJson));
      s.recipes
        ..clear()
        ..addAll(_listOf(m['recipes']).map(recipeFromJson));
      s.vouchers
        ..clear()
        ..addAll(_listOf(m['vouchers']).map(voucherFromJson));
      s.orders
        ..clear()
        ..addAll(_listOf(m['orders']).map(orderFromJson));
      s.stockTxs
        ..clear()
        ..addAll(_listOf(m['stockTxs']).map(stockTxFromJson));
      s.notifications
        ..clear()
        ..addAll(_listOf(m['notifications']).map(notificationFromJson));
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<Map<String, dynamic>> _listOf(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

List<Map<String, dynamic>> _listOf(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

// ===== enums helpers =====
E _enum<E extends Enum>(List<E> all, dynamic name, E fallback) {
  if (name is String) {
    for (final e in all) {
      if (e.name == name) return e;
    }
  }
  return fallback;
}

String? _dt(DateTime? d) => d?.toIso8601String();
DateTime? _prs(String? v) => v == null ? null : DateTime.tryParse(v);
double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
bool _bool(dynamic v) => v == true;
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

// ===== User =====
Map<String, dynamic> userToJson(AppUser u) => {
      'id': u.id,
      'fullName': u.fullName,
      'email': u.email,
      'phone': u.phone,
      'role': u.role.name,
      'avatarUrl': u.avatarUrl,
      'active': u.active,
      'createdAt': _dt(u.createdAt),
    };

AppUser userFromJson(Map<String, dynamic> m) => AppUser(
      id: m['id'] as String,
      fullName: m['fullName'] as String,
      email: m['email'] as String,
      phone: m['phone'] as String,
      role: _enum(UserRole.values, m['role'] as String?, UserRole.customer),
      avatarUrl: m['avatarUrl'] as String?,
      active: _bool(m['active']),
      createdAt: _prs(m['createdAt'] as String?),
    );

// ===== Category =====
Map<String, dynamic> categoryToJson(ProductCategory c) => {
      'id': c.id,
      'name': c.name,
      'description': c.description,
      'icon': c.icon,
      'active': c.active,
    };

ProductCategory categoryFromJson(Map<String, dynamic> m) => ProductCategory(
      id: m['id'] as String,
      name: m['name'] as String,
      description: m['description'] as String? ?? '',
      icon: m['icon'] as String? ?? '☕',
      active: _bool(m['active']),
    );

// ===== Topping =====
Map<String, dynamic> toppingToJson(Topping t) =>
    {'id': t.id, 'name': t.name, 'price': t.price, 'available': t.available};

Topping toppingFromJson(Map<String, dynamic> m) => Topping(
      id: m['id'] as String,
      name: m['name'] as String,
      price: _num(m['price']),
      available: _bool(m['available']),
    );

// ===== Product =====
Map<String, dynamic> productToJson(Product p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'imageUrl': p.imageUrl,
      'emoji': p.emoji,
      'categoryId': p.categoryId,
      'basePrice': p.basePrice,
      'priceBySize':
          p.priceBySize.map((k, v) => MapEntry(k.name, v)),
      'availableToppingIds': p.availableToppingIds,
      'inStock': p.inStock,
      'hidden': p.hidden,
      'createdAt': _dt(p.createdAt),
      'updatedAt': _dt(p.updatedAt),
    };

Product productFromJson(Map<String, dynamic> m) {
  final sizes = <DrinkSize, double>{};
  final pm = m['priceBySize'];
  if (pm is Map) {
    pm.forEach((k, v) {
      sizes[_enum(DrinkSize.values, k as String?, DrinkSize.m)] =
          (v as num).toDouble();
    });
  }
  return Product(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String? ?? '',
    imageUrl: m['imageUrl'] as String? ?? '',
    emoji: m['emoji'] as String? ?? '☕',
    categoryId: m['categoryId'] as String,
    basePrice: _num(m['basePrice']),
    priceBySize: sizes.isEmpty ? null : sizes,
    availableToppingIds:
        (m['availableToppingIds'] as List?)?.cast<String>() ?? const [],
    inStock: _bool(m['inStock']),
    hidden: _bool(m['hidden']),
    createdAt: _prs(m['createdAt'] as String?),
    updatedAt: _prs(m['updatedAt'] as String?),
  );
}

// ===== Table =====
Map<String, dynamic> tableToJson(CafeTable t) => {
      'id': t.id,
      'tableName': t.tableName,
      'capacity': t.capacity,
      'status': t.status.name,
      'currentOrderId': t.currentOrderId,
      'qrCodeValue': t.qrCodeValue,
    };

CafeTable tableFromJson(Map<String, dynamic> m) => CafeTable(
      id: m['id'] as String,
      tableName: m['tableName'] as String,
      capacity: _int(m['capacity']),
      status: _enum(TableStatus.values, m['status'] as String?, TableStatus.empty),
      currentOrderId: m['currentOrderId'] as String?,
      qrCodeValue: m['qrCodeValue'] as String?,
    );

// ===== Customer =====
Map<String, dynamic> customerToJson(Customer c) => {
      'id': c.id,
      'fullName': c.fullName,
      'phone': c.phone,
      'email': c.email,
      'points': c.points,
      'rank': c.rank.name,
      'totalSpent': c.totalSpent,
      'totalOrders': c.totalOrders,
      'favoriteProducts': c.favoriteProducts,
      'createdAt': _dt(c.createdAt),
    };

Customer customerFromJson(Map<String, dynamic> m) => Customer(
      id: m['id'] as String,
      fullName: m['fullName'] as String,
      phone: m['phone'] as String,
      email: m['email'] as String? ?? '',
      points: _int(m['points']),
      rank: _enum(CustomerRank.values, m['rank'] as String?, CustomerRank.bronze),
      totalSpent: _num(m['totalSpent']),
      totalOrders: _int(m['totalOrders']),
      favoriteProducts:
          (m['favoriteProducts'] as List?)?.cast<String>() ?? const [],
      createdAt: _prs(m['createdAt'] as String?),
    );

// ===== Ingredient =====
Map<String, dynamic> ingredientToJson(Ingredient i) => {
      'id': i.id,
      'name': i.name,
      'unit': i.unit,
      'currentStock': i.currentStock,
      'minStock': i.minStock,
      'costPerUnit': i.costPerUnit,
      'supplier': i.supplier,
      'expiredDate': _dt(i.expiredDate),
      'active': i.active,
      'createdAt': _dt(i.createdAt),
      'updatedAt': _dt(i.updatedAt),
    };

Ingredient ingredientFromJson(Map<String, dynamic> m) => Ingredient(
      id: m['id'] as String,
      name: m['name'] as String,
      unit: m['unit'] as String,
      currentStock: _num(m['currentStock']),
      minStock: _num(m['minStock']),
      costPerUnit: _num(m['costPerUnit']),
      supplier: m['supplier'] as String? ?? '',
      expiredDate: _prs(m['expiredDate'] as String?),
      active: _bool(m['active']),
      createdAt: _prs(m['createdAt'] as String?),
      updatedAt: _prs(m['updatedAt'] as String?),
    );

// ===== Recipe =====
Map<String, dynamic> recipeItemToJson(RecipeItem ri) =>
    {'ingredientId': ri.ingredientId, 'quantity': ri.quantity, 'unit': ri.unit};

RecipeItem recipeItemFromJson(Map<String, dynamic> m) => RecipeItem(
      ingredientId: m['ingredientId'] as String,
      quantity: _num(m['quantity']),
      unit: m['unit'] as String,
    );

Map<String, dynamic> recipeToJson(Recipe r) => {
      'id': r.id,
      'productId': r.productId,
      'size': r.size.name,
      'items': r.items.map(recipeItemToJson).toList(),
    };

Recipe recipeFromJson(Map<String, dynamic> m) => Recipe(
      id: m['id'] as String,
      productId: m['productId'] as String,
      size: _enum(DrinkSize.values, m['size'] as String?, DrinkSize.m),
      items: _listOf(m['items']).map(recipeItemFromJson).toList(),
    );

// ===== Voucher =====
Map<String, dynamic> voucherToJson(Voucher v) => {
      'id': v.id,
      'code': v.code,
      'name': v.name,
      'discountType': v.discountType.name,
      'discountValue': v.discountValue,
      'minOrderValue': v.minOrderValue,
      'maxDiscount': v.maxDiscount,
      'startDate': _dt(v.startDate),
      'endDate': _dt(v.endDate),
      'usageLimit': v.usageLimit,
      'usedCount': v.usedCount,
      'active': v.active,
    };

Voucher voucherFromJson(Map<String, dynamic> m) => Voucher(
      id: m['id'] as String,
      code: m['code'] as String,
      name: m['name'] as String? ?? '',
      discountType:
          _enum(DiscountType.values, m['discountType'] as String?, DiscountType.amount),
      discountValue: _num(m['discountValue']),
      minOrderValue: _num(m['minOrderValue']),
      maxDiscount: _num(m['maxDiscount']),
      startDate: _prs(m['startDate'] as String?) ?? DateTime.now(),
      endDate: _prs(m['endDate'] as String?) ?? DateTime.now(),
      usageLimit: _int(m['usageLimit']),
      usedCount: _int(m['usedCount']),
      active: _bool(m['active']),
    );

// ===== Order Item =====
Map<String, dynamic> orderItemToJson(OrderItem it) => {
      'id': it.id,
      'productId': it.productId,
      'productName': it.productName,
      'emoji': it.emoji,
      'size': it.size.name,
      'toppingIds': it.toppingIds,
      'toppingNames': it.toppingNames,
      'toppingsPrice': it.toppingsPrice,
      'sugar': it.sugar.name,
      'ice': it.ice.name,
      'quantity': it.quantity,
      'unitPrice': it.unitPrice,
      'note': it.note,
      'status': it.status,
    };

OrderItem orderItemFromJson(Map<String, dynamic> m) => OrderItem(
      id: m['id'] as String,
      productId: m['productId'] as String,
      productName: m['productName'] as String,
      emoji: m['emoji'] as String? ?? '☕',
      size: _enum(DrinkSize.values, m['size'] as String?, DrinkSize.m),
      toppingIds: (m['toppingIds'] as List?)?.cast<String>() ?? const [],
      toppingNames: (m['toppingNames'] as List?)?.cast<String>() ?? const [],
      toppingsPrice: _num(m['toppingsPrice']),
      sugar: _enum(SugarLevel.values, m['sugar'] as String?, SugarLevel.full),
      ice: _enum(IceLevel.values, m['ice'] as String?, IceLevel.normal),
      quantity: _int(m['quantity']),
      unitPrice: _num(m['unitPrice']),
      note: m['note'] as String? ?? '',
      status: m['status'] as String? ?? 'pending',
    );

// ===== Order =====
Map<String, dynamic> orderToJson(AppOrder o) => {
      'id': o.id,
      'orderCode': o.orderCode,
      'tableId': o.tableId,
      'tableName': o.tableName,
      'customerId': o.customerId,
      'customerName': o.customerName,
      'cashierId': o.cashierId,
      'cashierName': o.cashierName,
      'orderType': o.orderType.name,
      'items': o.items.map(orderItemToJson).toList(),
      'subtotal': o.subtotal,
      'discount': o.discount,
      'voucherCode': o.voucherCode,
      'total': o.total,
      'paymentMethod': o.paymentMethod?.name,
      'paymentStatus': o.paymentStatus.name,
      'orderStatus': o.orderStatus.name,
      'note': o.note,
      'createdAt': _dt(o.createdAt),
      'updatedAt': _dt(o.updatedAt),
      'completedAt': _dt(o.completedAt),
    };

AppOrder orderFromJson(Map<String, dynamic> m) => AppOrder(
      id: m['id'] as String,
      orderCode: m['orderCode'] as String,
      tableId: m['tableId'] as String?,
      tableName: m['tableName'] as String?,
      customerId: m['customerId'] as String?,
      customerName: m['customerName'] as String?,
      cashierId: m['cashierId'] as String,
      cashierName: m['cashierName'] as String,
      orderType: _enum(OrderType.values, m['orderType'] as String?, OrderType.dineIn),
      items: _listOf(m['items']).map(orderItemFromJson).toList(),
      subtotal: _num(m['subtotal']),
      discount: _num(m['discount']),
      voucherCode: m['voucherCode'] as String?,
      total: _num(m['total']),
      paymentMethod: m['paymentMethod'] == null
          ? null
          : _enum(PaymentMethod.values, m['paymentMethod'] as String, PaymentMethod.cash),
      paymentStatus:
          _enum(PaymentStatus.values, m['paymentStatus'] as String?, PaymentStatus.unpaid),
      orderStatus:
          _enum(OrderStatus.values, m['orderStatus'] as String?, OrderStatus.pending),
      note: m['note'] as String? ?? '',
      createdAt: _prs(m['createdAt'] as String?),
      updatedAt: _prs(m['updatedAt'] as String?),
      completedAt: _prs(m['completedAt'] as String?),
    );

// ===== Stock transaction =====
Map<String, dynamic> stockTxToJson(StockTransaction t) => {
      'id': t.id,
      'ingredientId': t.ingredientId,
      'ingredientName': t.ingredientName,
      'type': t.type.name,
      'quantity': t.quantity,
      'unit': t.unit,
      'note': t.note,
      'createdBy': t.createdBy,
      'createdAt': _dt(t.createdAt),
    };

StockTransaction stockTxFromJson(Map<String, dynamic> m) => StockTransaction(
      id: m['id'] as String,
      ingredientId: m['ingredientId'] as String,
      ingredientName: m['ingredientName'] as String? ?? '',
      type: _enum(StockTxType.values, m['type'] as String?, StockTxType.inbound),
      quantity: _num(m['quantity']),
      unit: m['unit'] as String? ?? '',
      note: m['note'] as String? ?? '',
      createdBy: m['createdBy'] as String? ?? 'system',
      createdAt: _prs(m['createdAt'] as String?),
    );

// ===== Notification =====
Map<String, dynamic> notificationToJson(AppNotification n) => {
      'id': n.id,
      'title': n.title,
      'message': n.message,
      'type': n.type,
      'targetRole': n.targetRole?.name,
      'isRead': n.isRead,
      'createdAt': _dt(n.createdAt),
    };

AppNotification notificationFromJson(Map<String, dynamic> m) => AppNotification(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      message: m['message'] as String? ?? '',
      type: m['type'] as String? ?? 'info',
      targetRole: m['targetRole'] == null
          ? null
          : _enum(UserRole.values, m['targetRole'] as String, UserRole.customer),
      isRead: _bool(m['isRead']),
      createdAt: _prs(m['createdAt'] as String?),
    );