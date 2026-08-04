import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcafe/core/constants/enums.dart';
import 'package:smartcafe/data/models/cafe_table.dart';
import 'package:smartcafe/data/models/category.dart';
import 'package:smartcafe/data/models/order.dart';
import 'package:smartcafe/data/models/order_item.dart';
import 'package:smartcafe/data/models/recipe.dart';
import 'package:smartcafe/data/models/user.dart';
import 'package:smartcafe/data/models/voucher.dart';
import 'package:smartcafe/data/services/data_store.dart';
import 'package:smartcafe/data/services/persistence.dart';
import 'package:smartcafe/features/auth/auth_provider.dart';

AppUser? _cashier(DataStore s) =>
    s.users.where((u) => u.role == UserRole.cashier).firstOrNull;

void main() {
  late DataStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DataStore();
    await store.init();
  });

  group('AuthProvider', () {
    test('đăng nhập sai mật khẩu / email không tồn tại bị từ chối', () {
      final auth = AuthProvider(store);
      expect(auth.login('admin@smartcafe.com', 'sai'), isNotNull);
      expect(auth.login('khong@ton-tai.vn', '123456'), isNotNull);
    });

    test('đăng nhập đúng -> isLoggedIn + role admin', () {
      final auth = AuthProvider(store);
      final err = auth.login('admin@smartcafe.com', '123456');
      expect(err, isNull);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.role, UserRole.admin);
    });

    test('tài khoản bị khóa bị chặn', () {
      final auth = AuthProvider(store);
      final u = _cashier(store)!;
      store.updateUser(u.copyWith(active: false));
      expect(auth.login(u.email, '123456'), isNotNull);
      expect(auth.isLoggedIn, isFalse);
    });
  });

  group('Voucher', () {
    test('giảm % có maxDiscount', () {
      final v = Voucher(
        id: 'v1',
        code: 'P10',
        name: 'Percent',
        discountType: DiscountType.percent,
        discountValue: 10,
        maxDiscount: 20000,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 30)),
        usageLimit: 100,
      );
      expect(v.calcDiscount(100000), 10000); // 10% = 10k (chưa vượt cap)
      expect(v.calcDiscount(500000), 20000); // 10% = 50k -> chặn 20k
    });

    test('giảm số tiền cố định, tôn trọng minOrder', () {
      final v = Voucher(
        id: 'v2',
        code: 'FIX',
        name: 'Fix',
        discountType: DiscountType.amount,
        discountValue: 15000,
        minOrderValue: 100000,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(v.calcDiscount(50000), 0); // chưa đạt đơn tối thiểu
      expect(v.calcDiscount(120000), 15000);
    });

    test('hết hạn thì isAvailable = false', () {
      final v = Voucher(
        id: 'v3',
        code: 'OLD',
        name: 'Old',
        discountType: DiscountType.amount,
        discountValue: 1000,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(v.isAvailable, isFalse);
    });
  });

  group('Order / Doanh thu', () {
    test('createOrder tính subtotal - discount = total, đổi trạng thái bàn',
        () {
      final cashier = _cashier(store)!;
      final table = store.tables.first;
      final product = store.products.first;
      final voucher = store.vouchers.first;
      final usedBefore = voucher.usedCount;

      final item = OrderItem(
        id: 'it1',
        productId: product.id,
        productName: product.name,
        emoji: product.emoji,
        size: DrinkSize.m,
        unitPrice: product.priceFor(DrinkSize.m),
        quantity: 2,
      );
      final order = store.createOrder(
        cashier: cashier,
        items: [item],
        orderType: OrderType.dineIn,
        tableId: table.id,
        voucher: voucher,
      );

      expect(order.subtotal, closeTo(item.totalPrice, 0.001));
      expect(
          order.total,
          closeTo(
              order.subtotal - voucher.calcDiscount(order.subtotal), 0.001));
      expect(order.orderStatus, OrderStatus.pending);
      expect(store.findTable(table.id)!.status, TableStatus.serving);
      expect(voucher.usedCount, usedBefore + 1);
      // Thông báo "đơn mới" đẩy cho barista
      expect(
        store
            .notificationsForRole(UserRole.barista)
            .any((n) => n.type == 'order_new'),
        isTrue,
      );
    });

    test('trừ kho theo công thức khi đơn chuyển sang preparing', () {
      final cashier = _cashier(store)!;
      final recipe = store.recipes.first;
      final product =
          store.products.firstWhere((p) => p.id == recipe.productId);
      final ing = store.findIngredient(recipe.items.first.ingredientId)!;
      final stockBefore = ing.currentStock;

      final item = OrderItem(
        id: 'it2',
        productId: product.id,
        productName: product.name,
        size: recipe.size,
        unitPrice: 10000,
        quantity: 1,
      );
      final order = store.createOrder(
        cashier: cashier,
        items: [item],
        orderType: OrderType.takeaway,
      );

      // Chưa trừ khi đơn mới tạo
      expect(
          store.findIngredient(recipe.items.first.ingredientId)!.currentStock,
          closeTo(stockBefore, 0.001));

      store.updateOrderStatus(order.id, OrderStatus.preparing);
      final used = recipe.items.first.quantity;
      expect(
          store.findIngredient(recipe.items.first.ingredientId)!.currentStock,
          closeTo(stockBefore - used, 0.001));
    });

    test('payOrder: cộng điểm khách (10k=1 điểm) + bàn cần dọn', () {
      final cashier = _cashier(store)!;
      final cust = store.customers.first;
      final table = store.tables.first;
      final pointsBefore = cust.points;

      final item = OrderItem(
        id: 'it3',
        productId: store.products.first.id,
        productName: store.products.first.name,
        size: DrinkSize.m,
        unitPrice: 10000,
        quantity: 1,
      );
      final order = store.createOrder(
        cashier: cashier,
        items: [item],
        orderType: OrderType.dineIn,
        tableId: table.id,
        customerId: cust.id,
      );
      store.payOrder(order.id, PaymentMethod.cash);

      expect(store.findTable(table.id)!.status, TableStatus.needsClean);
      final paid = store.orders.firstWhere((o) => o.id == order.id);
      expect(paid.paymentStatus, PaymentStatus.paid);
      expect(cust.points, pointsBefore + (paid.total / 10000).floor());
    });

    test('cancelOrder: bàn trở về trống', () {
      final cashier = _cashier(store)!;
      final table = store.tables.first;
      final item = OrderItem(
        id: 'it4',
        productId: store.products.first.id,
        productName: store.products.first.name,
        size: DrinkSize.m,
        unitPrice: 10000,
        quantity: 1,
      );
      final order = store.createOrder(
        cashier: cashier,
        items: [item],
        orderType: OrderType.dineIn,
        tableId: table.id,
      );
      expect(store.findTable(table.id)!.status, TableStatus.serving);
      store.cancelOrder(order.id);
      expect(store.findTable(table.id)!.status, TableStatus.empty);
      expect(
        store.orders.firstWhere((o) => o.id == order.id).orderStatus,
        OrderStatus.cancelled,
      );
    });
  });

  group('Thông minh', () {
    test('suggestRestock gồm nguyên liệu dưới ngưỡng', () {
      final low = store.ingredients.firstWhere((i) => i.isLow);
      expect(store.suggestRestock().any((e) => e.key.id == low.id), isTrue);
    });
  });

  group('Persistence', () {
    test('StoreCodec round-trip giữ nguyên dữ liệu', () {
      final s2 = DataStore();
      final ok = StoreCodec.decode(s2, StoreCodec.encode(store));
      expect(ok, isTrue);
      expect(s2.products.length, store.products.length);
      expect(s2.orders.length, store.orders.length);
      expect(s2.ingredients.length, store.ingredients.length);
      expect(s2.orderSeq, store.orderSeq);

      // Một đơn cụ thể khôi phục đúng
      final order = store.orders.first;
      final restored = s2.orders.firstWhere((o) => o.id == order.id);
      expect(restored.orderCode, order.orderCode);
      expect(restored.total, order.total);
      expect(restored.items.length, order.items.length);
      expect(restored.items.first.size, order.items.first.size);
    });

    test('decode dữ liệu rác trả về false không crash', () {
      final s2 = DataStore();
      expect(StoreCodec.decode(s2, 'khong-phai-json'), isFalse);
      expect(s2.products, isEmpty);
    });
  });

  group('CRUD Admin', () {
    test('thêm/sửa/xóa danh mục', () {
      final before = store.categories.length;
      store.addCategory(ProductCategory(id: 'cat-test', name: 'Test Cat'));
      expect(store.categories.length, before + 1);
      store.updateCategory(ProductCategory(id: 'cat-test', name: 'Test Cat 2'));
      expect(store.findCategory('cat-test')!.name, 'Test Cat 2');
      store.removeCategory('cat-test');
      expect(store.findCategory('cat-test'), isNull);
    });

    test('thêm/sửa/xóa công thức', () {
      final p = store.products.first;
      final ing = store.ingredients.first;
      store.addRecipe(Recipe(
        id: 'r-test',
        productId: p.id,
        size: DrinkSize.s,
        items: [RecipeItem(ingredientId: ing.id, quantity: 10, unit: ing.unit)],
      ));
      expect(store.findRecipe(p.id, DrinkSize.s)!.items.length, 1);
      store.updateRecipe(Recipe(
        id: 'r-test',
        productId: p.id,
        size: DrinkSize.s,
        items: [RecipeItem(ingredientId: ing.id, quantity: 20, unit: ing.unit)],
      ));
      expect(store.findRecipe(p.id, DrinkSize.s)!.items.first.quantity, 20);
      store.removeRecipe('r-test');
      expect(store.findRecipe(p.id, DrinkSize.s), isNull);
    });

    test('xóa voucher', () {
      final v = store.vouchers.first;
      store.removeVoucher(v.id);
      expect(store.findVoucherByCode(v.code), isNull);
    });
  });

  group('Bàn & điểm', () {
    AppOrder orderOn(DataStore s, CafeTable? t) {
      final cashier = _cashier(s)!;
      return s.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
              id: 'o-' + t!.id,
              productId: s.products.first.id,
              productName: 'P',
              size: DrinkSize.m,
              unitPrice: 10000,
              quantity: 1),
        ],
        orderType: OrderType.dineIn,
        tableId: t.id,
      );
    }

    test('chuyển bàn: đơn sang bàn mới, bàn cũ trống', () {
      final tA = store.tables[0];
      final tB = store.tables[1];
      final order = orderOn(store, tA);
      expect(store.findTable(tA.id)!.status, TableStatus.serving);
      expect(store.findTable(tB.id)!.status, TableStatus.empty);

      store.moveOrderToTable(order.id, tB.id);

      expect(store.findTable(tA.id)!.status, TableStatus.empty);
      expect(store.findTable(tB.id)!.status, TableStatus.serving);
      expect(store.findTable(tB.id)!.currentOrderId, order.id);
      final moved = store.orders.firstWhere((o) => o.id == order.id);
      expect(moved.tableId, tB.id);
      expect(moved.tableName, tB.tableName);
    });

    test('gộp bàn: gộp món về bàn đích, bàn nguồn trống', () {
      final tA = store.tables[0];
      final tB = store.tables[1];
      final oA = orderOn(store, tA);
      final oB = orderOn(store, tB);

      store.mergeTables(tA.id, tB.id);

      expect(store.findTable(tA.id)!.status, TableStatus.empty);
      expect(store.findTable(tB.id)!.status, TableStatus.serving);
      final mergedId = store.findTable(tB.id)!.currentOrderId!;
      final merged = store.orders.firstWhere((o) => o.id == mergedId);
      expect(merged.items.length, oA.items.length + oB.items.length);
      expect(
        store.orders.firstWhere((o) => o.id == oA.id).orderStatus,
        OrderStatus.cancelled,
      );
    });

    test('dùng điểm giảm giá: total trừ điểm + payOrder trừ điểm khách', () {
      final cust = store.customers.first;
      cust.addPoints(300); // đủ 300 điểm
      final ptsUsed = 200;
      final discount = ((ptsUsed ~/ 100) * 10000).toDouble(); // 20.000đ

      final cashier = _cashier(store)!;
      final item = OrderItem(
          id: 'pt1',
          productId: store.products.first.id,
          productName: 'P',
          size: DrinkSize.m,
          unitPrice: 100000,
          quantity: 1);
      final order = store.createOrder(
        cashier: cashier,
        items: [item],
        orderType: OrderType.takeaway,
        customerId: cust.id,
        pointsUsed: ptsUsed,
        pointsDiscount: discount,
      );

      expect(order.pointsUsed, ptsUsed);
      expect(order.pointsDiscount, discount);
      expect(order.total, closeTo(order.subtotal - discount, 0.001));

      final before = cust.points;
      store.payOrder(order.id, PaymentMethod.cash);
      final earned = (order.total / 10000).floor();
      expect(cust.points, before + earned - ptsUsed);
    });
  });
}
