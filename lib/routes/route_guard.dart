import '../core/constants/enums.dart';

/// Phân quyền route theo vai trò.
/// - Mỗi route khai báo danh sách role được phép vào.
/// - Route không khai báo => deny (fail-closed), router để rơi vào 404.
/// - /profile là route chung cho mọi role đã đăng nhập.
class RouteGuard {
  static const Map<String, List<UserRole>> _allowed = {
    '/admin': [UserRole.admin],
    '/cashier': [UserRole.admin, UserRole.cashier, UserRole.waiter],
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
    // '/' + '/login' không cần check role trong router (xử lý riêng),
    // nhưng khai báo ở đây để allowed() cũng đúng khi gọi trực tiếp.
    '/': UserRole.values,
    '/login': UserRole.values,
    '/settings': UserRole.values,
    '/profile': UserRole.values,
    '/forgot': UserRole.values,
  };

  /// Route có tồn tại trong bảng phân quyền không (hỗ trợ path parameter).
  static bool isKnown(String location) {
    final path = location.split('?').first;
    for (final route in _allowed.keys) {
      if (path == route || path.startsWith(route + '/')) return true;
    }
    return false;
  }

  /// Kiểm tra role có được vào [location] hay không.
  /// Hỗ trợ route có path parameter (vd /orders/:id khớp prefix /orders).
  /// Route lạ => false (deny); caller dùng [isKnown] để phân biệt 404.
  static bool allowed(String location, UserRole role) {
    final path = location.split('?').first;
    for (final entry in _allowed.entries) {
      final route = entry.key;
      if (path == route || path.startsWith(route + '/')) {
        return entry.value.contains(role);
      }
    }
    return false; // fail-closed: route lạ không cho vào
  }
}
