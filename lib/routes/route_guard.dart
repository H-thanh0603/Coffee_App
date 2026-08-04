import '../core/constants/enums.dart';

/// Phân quyền route theo vai trò.
/// - Mỗi route khai báo danh sách role được phép vào.
/// - Route không khai báo (không tồn tại) => mặc định cho phép nếu đã đăng nhập.
/// - /profile là route chung cho mọi role đã đăng nhập.
class RouteGuard {
  static const Map<String, List<UserRole>> _allowed = {
    '/admin': [UserRole.admin],
    '/cashier': [UserRole.admin, UserRole.cashier],
    '/barista': [UserRole.admin, UserRole.barista],
    '/waiter': [UserRole.admin, UserRole.waiter],
    '/customer': [UserRole.admin, UserRole.customer],
    '/orders': [UserRole.admin, UserRole.cashier, UserRole.waiter],
    '/products': [UserRole.admin],
    '/categories': [UserRole.admin],
    '/toppings': [UserRole.admin],
    '/inventory': [UserRole.admin],
    '/recipes': [UserRole.admin],
    '/customers': [UserRole.admin, UserRole.cashier],
    '/vouchers': [UserRole.admin],
    '/reports': [UserRole.admin],
    '/employees': [UserRole.admin],
    '/tables': [UserRole.admin, UserRole.cashier, UserRole.waiter],
    '/settings': UserRole.values,
    '/profile': UserRole.values,
  };

  /// Kiểm tra role có được vào [location] hay không.
  /// Hỗ trợ route có path parameter (vd /orders/:id khớp prefix /orders).
  static bool allowed(String location, UserRole role) {
    final path = location.split('?').first;
    for (final entry in _allowed.entries) {
      final route = entry.key;
      if (path == route || path.startsWith(route + '/')) {
        return entry.value.contains(role);
      }
    }
    return true; // route không bị giới hạn
  }
}
