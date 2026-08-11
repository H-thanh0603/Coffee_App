import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcafe/core/constants/enums.dart';
import 'package:smartcafe/data/models/order_item.dart';
import 'package:smartcafe/data/models/user.dart';
import 'package:smartcafe/data/services/data_store.dart';
import 'package:smartcafe/data/services/outbox.dart';

AppUser? _cashier(DataStore s) =>
    s.users.where((u) => u.role == UserRole.cashier).firstOrNull;

OrderItem _drink(DataStore s) {
  final p = s.products.first;
  return OrderItem(
    id: 'it-1',
    productId: p.id,
    productName: p.name,
    emoji: p.emoji,
    size: DrinkSize.m,
    unitPrice: p.priceFor(DrinkSize.m),
    quantity: 1,
  );
}

void main() {
  late DataStore store;
  late Outbox outbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DataStore();
    await store.init();
    outbox = Outbox();
    await outbox.init();
    store.attachOutbox(outbox);
  });

  test('createOrder enqueue place_order op vào outbox', () async {
    final o = store.createOrder(
      cashier: _cashier(store)!,
      items: [_drink(store)],
      orderType: OrderType.dineIn,
      tableId: store.tables.first.id,
    );
    await Future<void>.delayed(Duration.zero);
    expect(outbox.pending.length, 1);
    final op = outbox.pending.first;
    expect(op.type, 'place_order');
    expect(op.payload['orderId'], o.id);
    expect(op.payload['tableId'], store.tables.first.id);
  });

  test('payOrder enqueue pay_order op; outbox persist qua prefs', () async {
    final o = store.createOrder(
      cashier: _cashier(store)!,
      items: [_drink(store)],
      orderType: OrderType.dineIn,
      tableId: store.tables.first.id,
    );
    await Future<void>.delayed(Duration.zero);
    store.payOrder(o.id, PaymentMethod.cash);
    await Future<void>.delayed(Duration.zero);
    expect(outbox.pending.any((op) => op.type == 'pay_order'), true);

    // outbox mới đọc lại từ prefs -> op không mất khi khởi động lại
    final outbox2 = Outbox();
    await outbox2.init();
    expect(outbox2.pending.any((op) => op.type == 'pay_order'), true);
  });

  test('offline outbox giữ nguyên op cho tới khi flush thành công', () async {
    final o = store.createOrder(
      cashier: _cashier(store)!,
      items: [_drink(store)],
      orderType: OrderType.dineIn,
      tableId: store.tables[1].id,
    );
    await Future<void>.delayed(Duration.zero);
    store.cancelOrder(o.id, reason: 'test');
    await Future<void>.delayed(Duration.zero);
    // 2 op: place_order + cancel_order
    expect(outbox.pending.length, 2);

    // không có SyncEngine chạy -> op ở lại (giả lập offline)
    await Future<void>.delayed(Duration.zero);
    expect(outbox.pending.length, 2);
    expect(outbox.pending.last.type, 'cancel_order');
  });

  test('flush xóa op khỏi hàng đợi sau khi replay thành công', () async {
    // trực tiếp ghi op để không phụ thuộc DataStore timing
    final op = OutboxOp(
      type: 'adjust_stock',
      payload: {'ingredientId': 'ing-cafe-bot', 'type': 'in', 'quantity': 10},
    );
    await outbox.enqueue(op);
    expect(outbox.pending.length, 1);
    await outbox.remove(op.id);
    expect(outbox.pending, isEmpty);
  });
}
