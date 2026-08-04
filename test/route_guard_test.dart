import 'package:flutter_test/flutter_test.dart';

import 'package:smartcafe/core/constants/enums.dart';
import 'package:smartcafe/routes/route_guard.dart';

void main() {
  group('RouteGuard', () {
    test('cashier không vào được màn admin-only', () {
      for (final loc in ['/admin', '/products', '/inventory', '/recipes',
          '/vouchers', '/reports', '/employees']) {
        expect(RouteGuard.allowed(loc, UserRole.cashier), isFalse,
            reason: '$loc phải chặn cashier');
      }
    });

    test('cashier được vào POS/orders/tables/customers', () {
      expect(RouteGuard.allowed('/cashier', UserRole.cashier), isTrue);
      expect(RouteGuard.allowed('/orders', UserRole.cashier), isTrue);
      expect(RouteGuard.allowed('/orders/abc', UserRole.cashier), isTrue);
      expect(RouteGuard.allowed('/tables', UserRole.cashier), isTrue);
      expect(RouteGuard.allowed('/customers', UserRole.cashier), isTrue);
      expect(RouteGuard.allowed('/profile', UserRole.cashier), isTrue);
    });

    test('barista chỉ được pha chế + profile', () {
      expect(RouteGuard.allowed('/barista', UserRole.barista), isTrue);
      expect(RouteGuard.allowed('/profile', UserRole.barista), isTrue);
      expect(RouteGuard.allowed('/cashier', UserRole.barista), isFalse);
      expect(RouteGuard.allowed('/admin', UserRole.barista), isFalse);
      expect(RouteGuard.allowed('/orders', UserRole.barista), isFalse);
    });

    test('waiter chỉ bàn + đơn + profile', () {
      expect(RouteGuard.allowed('/waiter', UserRole.waiter), isTrue);
      expect(RouteGuard.allowed('/orders', UserRole.waiter), isTrue);
      expect(RouteGuard.allowed('/admin', UserRole.waiter), isFalse);
      expect(RouteGuard.allowed('/reports', UserRole.waiter), isFalse);
    });

    test('customer chỉ menu khách + profile', () {
      expect(RouteGuard.allowed('/customer', UserRole.customer), isTrue);
      expect(RouteGuard.allowed('/profile', UserRole.customer), isTrue);
      expect(RouteGuard.allowed('/admin', UserRole.customer), isFalse);
      expect(RouteGuard.allowed('/cashier', UserRole.customer), isFalse);
    });

    test('admin vào được mọi route hệ thống', () {
      for (final loc in ['/admin', '/cashier', '/barista', '/waiter',
          '/customer', '/orders', '/products', '/inventory', '/recipes',
          '/customers', '/vouchers', '/reports', '/employees', '/tables',
          '/profile']) {
        expect(RouteGuard.allowed(loc, UserRole.admin), isTrue,
            reason: '$loc phải mở cho admin');
      }
    });

    test('route không tồn tại => không chặn (sẽ rơi vào 404)', () {
      expect(RouteGuard.allowed('/khong-ton-tai', UserRole.cashier), isTrue);
    });

    test('query string không ảnh hưởng phân quyền', () {
      expect(RouteGuard.allowed('/orders?x=1', UserRole.cashier), isTrue);
    });
  });
}
