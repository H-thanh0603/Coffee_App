import 'package:flutter_test/flutter_test.dart';

import 'package:smartcafe/core/constants/enums.dart';
import 'package:smartcafe/data/models/product.dart';
import 'package:smartcafe/data/models/voucher.dart';
import 'package:smartcafe/features/cart/cart_provider.dart';

Voucher _voucher({required bool available}) => Voucher(
      id: 'v-cart',
      code: 'P10',
      name: 'Percent',
      discountType: DiscountType.percent,
      discountValue: 10,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: available
          ? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().subtract(const Duration(days: 1)),
      usageLimit: available ? 100 : 0,
    );

void main() {
  final product = Product(
    id: 'p1',
    name: 'Cà phê sữa',
    description: '',
    categoryId: 'c1',
    basePrice: 50000,
  );

  test('voucher còn hiệu lực: discount + total tính giảm giá', () {
    final cart = CartProvider();
    cart.addItem(
      product: product,
      size: DrinkSize.m,
      toppings: const [],
      sugar: SugarLevel.full,
      ice: IceLevel.normal,
    );
    final v = _voucher(available: true);
    cart.setVoucher(v);

    expect(cart.subtotal, 55000); // giá size M = basePrice + 5000
    expect(cart.discount, 5500); // 10%
    expect(cart.total, 49500);
  });

  test(
      'voucher hết hiệu lực: discount = 0, total = subtotal (không hiển thị giá sai)',
      () {
    final cart = CartProvider();
    cart.addItem(
      product: product,
      size: DrinkSize.m,
      toppings: const [],
      sugar: SugarLevel.full,
      ice: IceLevel.normal,
    );
    cart.setVoucher(_voucher(available: false));

    expect(cart.discount, 0);
    expect(cart.total, cart.subtotal);
  });

  test('bỏ voucher -> discount về 0', () {
    final cart = CartProvider();
    cart.addItem(
      product: product,
      size: DrinkSize.m,
      toppings: const [],
      sugar: SugarLevel.full,
      ice: IceLevel.normal,
    );
    cart.setVoucher(_voucher(available: true));
    cart.setVoucher(null);

    expect(cart.discount, 0);
    expect(cart.total, cart.subtotal);
  });
}
