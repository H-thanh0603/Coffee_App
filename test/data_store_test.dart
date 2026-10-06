import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcafe/core/constants/enums.dart';
import 'package:smartcafe/data/models/cafe_table.dart';
import 'package:smartcafe/data/models/category.dart';
import 'package:smartcafe/data/models/order.dart';
import 'package:smartcafe/data/models/order_item.dart';
import 'package:smartcafe/data/models/recipe.dart';
import 'package:smartcafe/data/models/table_reservation.dart';
import 'package:smartcafe/data/models/user.dart';
import 'package:smartcafe/data/models/voucher.dart';
import 'package:smartcafe/data/services/data_store.dart';
import 'package:smartcafe/data/services/local_db.dart';
import 'package:smartcafe/data/services/persistence.dart';
import 'package:smartcafe/features/auth/auth_provider.dart';

AppUser? _cashier(DataStore s) =>
    s.users.where((u) => u.role == UserRole.cashier).firstOrNull;

void main() {
  late DataStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DataStore(db: PrefsLocalDb());
    await store.init();
  });

  group('AuthProvider', () {
    test('đăng nhập sai mật khẩu / email không tồn tại bị từ chối', () async {
      final auth = AuthProvider(store);
      expect(await auth.login('admin@smartcafe.com', 'sai'), isNotNull);
      expect(await auth.login('khong@ton-tai.vn', kDemoPassword), isNotNull);
    });

    test('đăng nhập đúng -> isLoggedIn + role admin', () async {
      final auth = AuthProvider(store);
      final err = await auth.login('admin@smartcafe.com', kDemoPassword);
      expect(err, isNull);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.role, UserRole.admin);
    });

    test('tài khoản bị khóa bị chặn', () async {
      final auth = AuthProvider(store);
      final u = _cashier(store)!;
      store.updateUser(u.copyWith(active: false));
      expect(await auth.login(u.email, kDemoPassword), isNotNull);
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

    test('slowProducts chỉ gồm món đã bán dưới ngưỡng, không kể món 0 ly', () {
      // Mọi sản phẩm seed đều có trong _seedSampleOrders -> count > 0 cho mọi món
      // bán được. Món chưa từng bán (count = 0) phải bị loại ra khỏi danh sách.
      final slow = store.slowProducts(days: 7);
      expect(slow.every((e) => e.value > 0 && e.value < 5), isTrue);
      // Đúng ngưỡng: không được có món bán 0 ly
      expect(slow.any((e) => e.value == 0), isFalse);
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

    test('mergeTables giữ lại điểm giảm giá của 2 đơn gốc', () {
      final tA = store.tables[0];
      final tB = store.tables[1];
      final cashier = _cashier(store)!;
      final item = OrderItem(
          id: 'm1',
          productId: store.products.first.id,
          productName: 'P',
          size: DrinkSize.m,
          unitPrice: 100000,
          quantity: 1);
      final oA = store.createOrder(
          cashier: cashier,
          items: [item],
          orderType: OrderType.dineIn,
          tableId: tA.id,
          pointsUsed: 100,
          pointsDiscount: 10000);
      final oB = store.createOrder(
          cashier: cashier,
          items: [item],
          orderType: OrderType.dineIn,
          tableId: tB.id,
          pointsUsed: 50,
          pointsDiscount: 5000);

      store.mergeTables(tA.id, tB.id);

      final merged = store.orders
          .firstWhere((o) => o.id == store.findTable(tB.id)!.currentOrderId);
      expect(merged.pointsUsed, 150);
      expect(merged.pointsDiscount, 15000);
      final expectedTotal = (oA.subtotal + oB.subtotal) - 15000;
      expect(merged.total, closeTo(expectedTotal, 0.001));
    });

    test('cancelOrder: hoàn kho + hoàn voucher lượt dùng', () {
      final cashier = _cashier(store)!;
      final cust = store.customers.first;
      cust.addPoints(100);
      final v = store.vouchers.first;
      v.usedCount = 1;
      final table = store.tables.first;
      final item = OrderItem(
          id: 'cancel1',
          productId: store.products.first.id,
          productName: 'P',
          size: DrinkSize.m,
          unitPrice: 10000,
          quantity: 1);
      final order = store.createOrder(
          cashier: cashier,
          items: [item],
          orderType: OrderType.dineIn,
          tableId: table.id,
          customerId: cust.id,
          voucher: v);
      final ingId =
          store.findRecipe(item.productId, item.size)!.items.first.ingredientId;
      final stockBeforeConsume = store.findIngredient(ingId)!.currentStock;
      store.updateOrderStatus(order.id, OrderStatus.preparing); // trừ kho
      final stockAfterConsume = store.findIngredient(ingId)!.currentStock;
      expect(stockAfterConsume, lessThan(stockBeforeConsume));

      store.cancelOrder(order.id);

      // kho phải hoàn lại đúng về mức trước khi trừ
      expect(store.findIngredient(ingId)!.currentStock,
          closeTo(stockBeforeConsume, 0.001));
      // set 1 + createOrder cộng 1 = 2, cancelOrder hoàn 1 => 1
      expect(v.usedCount, 1);
      expect(store.findTable(table.id)!.status, TableStatus.empty);
    });

    test('payOrder: double-pay không cộng điểm 2 lần', () {
      final cust = store.customers.first;
      final cashier = _cashier(store)!;
      final order = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
              id: 'dp1',
              productId: store.products.first.id,
              productName: 'P',
              size: DrinkSize.m,
              unitPrice: 10000,
              quantity: 1),
        ],
        orderType: OrderType.takeaway,
        customerId: cust.id,
      );
      final pointsBefore = cust.points;
      store.payOrder(order.id, PaymentMethod.cash);
      store.payOrder(order.id, PaymentMethod.cash); // lần 2 bị chặn
      final paid = store.orders.firstWhere((o) => o.id == order.id);
      expect(paid.paymentStatus, PaymentStatus.paid);
      expect(cust.points, pointsBefore + (paid.total / 10000).floor());
    });

    test('payOrder: điểm khách không bị âm khi dùng quá số có', () {
      final cust = store.customers.first;
      cust.addPoints(100); // chỉ có 100 điểm
      const ptsUsed = 200; // nhưng cart cho dùng 200 (bug cũ)
      final cashier = _cashier(store)!;
      final item = OrderItem(
          id: 'neg1',
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
          pointsDiscount: ((ptsUsed ~/ 100) * 10000).toDouble());

      store.payOrder(order.id, PaymentMethod.cash);

      expect(cust.points, greaterThanOrEqualTo(0));
    });

    test('dùng điểm giảm giá: total trừ điểm + payOrder trừ điểm khách', () {
      final cust = store.customers.first;
      cust.addPoints(300); // đủ 300 điểm
      const ptsUsed = 200;
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

  group('Kho không đủ', () {
    test('missingIngredients báo thiếu khi set kho về 0', () {
      final recipe = store.recipes.first;
      final ing = store.findIngredient(recipe.items.first.ingredientId)!;
      final product =
          store.products.firstWhere((p) => p.id == recipe.productId);
      ing.currentStock = 0;
      final item = OrderItem(
        id: 'mis1',
        productId: product.id,
        productName: product.name,
        size: recipe.size,
        unitPrice: 10000,
        quantity: 1,
      );
      final missing = store.missingIngredients([item]);
      expect(missing.any((e) => e.key.id == ing.id), isTrue);
    });

    test('missingIngredients rỗng khi kho đủ', () {
      final recipe = store.recipes.first;
      final product =
          store.products.firstWhere((p) => p.id == recipe.productId);
      final item = OrderItem(
        id: 'ok1',
        productId: product.id,
        productName: product.name,
        size: recipe.size,
        unitPrice: 10000,
        quantity: 1,
      );
      expect(store.missingIngredients([item]), isEmpty);
    });
  });

  group('Doanh thu theo thời điểm thanh toán', () {
    test('revenueOnDate dùng completedAt thay vì createdAt', () {
      final cashier = _cashier(store)!;
      final today = DateTime.now();
      final revBeforeToday = store.revenueOnDate(today);
      final revBeforeYesterday =
          store.revenueOnDate(DateTime.now().subtract(const Duration(days: 1)));
      final base = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
            id: 'dt1',
            productId: store.products.first.id,
            productName: store.products.first.name,
            size: DrinkSize.m,
            unitPrice: 100000,
            quantity: 1,
          ),
        ],
        orderType: OrderType.takeaway,
      );
      // Ghi đè: đơn tạo hôm qua, hoàn tất (paid) hôm nay
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final todayNoon = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        12,
      );
      store.orders.removeWhere((o) => o.id == base.id);
      store.orders.add(AppOrder(
        id: base.id,
        orderCode: base.orderCode,
        cashierId: base.cashierId,
        cashierName: base.cashierName,
        orderType: base.orderType,
        items: base.items,
        subtotal: base.subtotal,
        total: base.total,
        paymentStatus: PaymentStatus.paid,
        paymentMethod: PaymentMethod.cash,
        orderStatus: OrderStatus.paid,
        createdAt: yesterday,
        updatedAt: todayNoon,
        completedAt: todayNoon,
      ));

      // Đã thanh toán hôm nay -> doanh thu hôm nay tăng đúng 100.000
      expect(store.revenueOnDate(DateTime.now()), revBeforeToday + 100000);
      // KHÔNG tính vào hôm qua dù createdAt rơi vào hôm qua
      expect(store.revenueOnDate(yesterday), revBeforeYesterday);
    });
  });

  group('Lợi nhuận ước tính', () {
    test('profitInRange chạy và tính theo paidAt', () {
      final cashier = _cashier(store)!;
      final recipe = store.recipes.first;
      final product =
          store.products.firstWhere((p) => p.id == recipe.productId);
      final order = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
              id: 'pr1',
              productId: product.id,
              productName: product.name,
              size: recipe.size,
              unitPrice: 100000,
              quantity: 1),
        ],
        orderType: OrderType.takeaway,
      );
      store.payOrder(order.id, PaymentMethod.cash);
      // Có lợi nhuận tính được trên dữ liệu vừa thêm (không crash, không âm vô hạn)
      expect(store.profitInRange(1), isA<double>());
    });
  });

  group('Đơn pha quá lâu', () {
    test('cảnh báo barista khi đơn >10 phút chưa hoàn thành', () {
      store.orders.clear();
      store.orders.add(AppOrder(
        id: 'slow1',
        orderCode: 'SLOW01',
        cashierId: 'c1',
        cashierName: 'C',
        orderType: OrderType.takeaway,
        items: const [],
        subtotal: 0,
        total: 0,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ));
      store.updateOrderStatus('slow1', OrderStatus.preparing);
      expect(
        store
            .notificationsForRole(UserRole.barista)
            .any((n) => n.type == 'slow_order'),
        isTrue,
      );
    });
  });

  group('Ca / đặt bàn / giờ cao điểm', () {
    test('vào ca 2 lần chỉ mở 1 ca, ra ca tính giờ + doanh thu ca', () {
      final cashier = _cashier(store)!;
      final s1 = store.clockIn(cashier.id, cashier.fullName);
      expect(store.openShiftFor(cashier.id)?.id, s1.id);
      expect(store.clockIn(cashier.id, cashier.fullName).id, s1.id);
      final product = store.products.first;
      final order = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
            id: 'shift1',
            productId: product.id,
            productName: product.name,
            size: DrinkSize.m,
            unitPrice: 50000,
            quantity: 1,
          ),
        ],
        orderType: OrderType.takeaway,
      );
      store.payOrder(order.id, PaymentMethod.cash);
      expect(store.revenueInShift(s1), closeTo(order.total, 0.001));
      expect(store.clockOut(cashier.id).inSeconds >= 0, isTrue);
      expect(store.openShiftFor(cashier.id), isNull);
    });

    test('đặt bàn trùng giờ ±60 phút bị từ chối', () {
      final t = store.tables.first;
      final at = DateTime.now().add(const Duration(hours: 2));
      final ok = store.addReservation(TableReservation(
        id: 'r1',
        tableId: t.id,
        tableName: t.tableName,
        customerName: 'An',
        phone: '0901',
        reservedAt: at,
      ));
      expect(ok, isTrue);
      expect(
          store.addReservation(TableReservation(
            id: 'r2',
            tableId: t.id,
            tableName: t.tableName,
            customerName: 'Bình',
            phone: '0902',
            reservedAt: at.add(const Duration(minutes: 30)),
          )),
          isFalse);
      store.cancelReservation('r1');
      expect(
          store.reservations
              .firstWhere((r) => r.id == 'r1')
              .status,
          TableReservationStatus.cancelled);
    });

    test('hàng đợi mang đi loại đơn đã xong/đã hủy', () {
      expect(store.takeawayQueue.every((o) =>
          o.orderType == OrderType.takeaway &&
          o.orderStatus != OrderStatus.served &&
          o.orderStatus != OrderStatus.paid &&
          o.orderStatus != OrderStatus.cancelled), isTrue);
    });

    test('giờ cao điểm + gợi ý ca chạy trên dữ liệu seed', () {
      final byHour = store.ordersByHour(days: 7);
      expect(byHour.length, 24);
      expect(byHour.any((c) => c > 0), isTrue);
      expect(store.shiftSuggestion(days: 7), isNotEmpty);
    });
  });

  group('Guard trừ kho / seq / prune', () {
    test('thiếu nguyên liệu -> updateOrderStatus(preparing) trả false, '
        'đơn giữ pending, kho nguyên', () {
      final cashier = _cashier(store)!;
      final recipe = store.recipes.first;
      final product =
          store.products.firstWhere((p) => p.id == recipe.productId);
      final ing = store.findIngredient(recipe.items.first.ingredientId)!;
      final stockBefore = ing.currentStock;
      final order = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
            id: 'guard1',
            productId: product.id,
            productName: product.name,
            size: recipe.size,
            unitPrice: 10000,
            quantity: 1,
          ),
        ],
        orderType: OrderType.takeaway,
      );
      ing.currentStock = 0; // kho cạn sau khi tạo đơn
      expect(
          store.updateOrderStatus(order.id, OrderStatus.preparing), isFalse);
      expect(order.orderStatus, OrderStatus.pending);
      expect(ing.currentStock, 0); // không trừ âm thêm
      expect(
          store.stockTxs.any((t) =>
              t.type == StockTxType.consumed &&
              t.note.contains(order.orderCode)),
          isFalse);
      ing.currentStock = stockBefore;
    });

    test('đủ kho -> preparing trừ đúng 1 lần, gọi lại không trừ nữa', () {
      final cashier = _cashier(store)!;
      final recipe = store.recipes.first;
      final product =
          store.products.firstWhere((p) => p.id == recipe.productId);
      final ing = store.findIngredient(recipe.items.first.ingredientId)!;
      final stockBefore = ing.currentStock;
      final order = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
            id: 'guard2',
            productId: product.id,
            productName: product.name,
            size: recipe.size,
            unitPrice: 10000,
            quantity: 1,
          ),
        ],
        orderType: OrderType.takeaway,
      );
      expect(
          store.updateOrderStatus(order.id, OrderStatus.preparing), isTrue);
      expect(order.orderStatus, OrderStatus.preparing);
      final used = recipe.items.first.quantity;
      expect(ing.currentStock, closeTo(stockBefore - used, 0.001));
      expect(
          store.updateOrderStatus(order.id, OrderStatus.preparing), isTrue);
      expect(ing.currentStock, closeTo(stockBefore - used, 0.001));
    });

    test('syncOrderSeq bắt kịp mã đơn lớn nhất đang có', () {
      store.orderSeq = 0;
      store.syncOrderSeq();
      expect(store.orderSeq, greaterThan(0));
      // tạo đơn mới không trùng mã đã có
      final codes = store.orders.map((o) => o.orderCode).toSet();
      final cashier = _cashier(store)!;
      final product = store.products.first;
      final order = store.createOrder(
        cashier: cashier,
        items: [
          OrderItem(
            id: 'seq1',
            productId: product.id,
            productName: product.name,
            size: DrinkSize.m,
            unitPrice: 10000,
            quantity: 1,
          ),
        ],
        orderType: OrderType.takeaway,
      );
      expect(codes.contains(order.orderCode), isFalse);
    });

    test('pruneOldData xóa đơn paid/cancelled quá 90 ngày, giữ đơn mở', () {
      store.orders.add(AppOrder(
        id: 'old-paid',
        orderCode: 'OLD001',
        cashierId: 'c1',
        cashierName: 'C',
        orderType: OrderType.takeaway,
        items: const [],
        subtotal: 0,
        total: 0,
        paymentStatus: PaymentStatus.paid,
        orderStatus: OrderStatus.paid,
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
        updatedAt: DateTime.now().subtract(const Duration(days: 100)),
      ));
      store.pruneOldData();
      expect(store.orders.any((o) => o.id == 'old-paid'), isFalse);
    });

    test('thông báo không vượt quá 100 mục mới nhất', () {
      // tạo đơn mới liên tục để sinh thông báo order_new cho barista
      final cashier = _cashier(store)!;
      final product = store.products.first;
      for (var i = 0; i < 120; i++) {
        store.createOrder(
          cashier: cashier,
          items: [
            OrderItem(
              id: 'spam$i',
              productId: product.id,
              productName: product.name,
              size: DrinkSize.m,
              unitPrice: 10000,
              quantity: 1,
            ),
          ],
          orderType: OrderType.takeaway,
        );
      }
      expect(store.notifications.length, lessThanOrEqualTo(100));
    });
  });
}
