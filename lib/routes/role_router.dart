import '../core/constants/enums.dart';

class RoleRouter {
  static String homeFor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '/admin';
      case UserRole.cashier:
        return '/cashier';
      case UserRole.barista:
        return '/barista';
      case UserRole.waiter:
        return '/waiter';
      case UserRole.customer:
        return '/customer';
    }
  }
}
