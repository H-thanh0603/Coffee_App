import 'package:flutter/foundation.dart';

import '../../core/auth/auth_gateway.dart';
import '../../core/constants/enums.dart';
import '../../data/models/user.dart';
import '../../data/services/data_store.dart';

class AuthProvider extends ChangeNotifier {
  final AuthGateway _gateway;
  AppUser? _currentUser;
  bool _loading = false;

  AuthProvider(DataStore store) : _gateway = AuthGatewayFake(store);

  AuthProvider.withGateway(AuthGateway gateway) : _gateway = gateway;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;
  bool get loading => _loading;

  /// Đăng nhập. Trả về null nếu thành công, chuỗi lỗi nếu thất bại.
  Future<String?> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    final err = await _gateway.signIn(email, password);
    if (err == null) {
      _currentUser = await _gateway.currentUser();
    }
    _loading = false;
    notifyListeners();
    return err;
  }

  /// Khôi phục session khi mở app (splash). Trả về user nếu đã đăng nhập.
  Future<AppUser?> restoreSession() async {
    final u = await _gateway.restoreSession();
    _currentUser = u;
    notifyListeners();
    return u;
  }

  Future<void> logout() async {
    await _gateway.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Chỉ admin được chuyển đổi tài khoản (tránh staff tự tăng quyền).
  void switchAccount(AppUser user) {
    if (_currentUser?.role != UserRole.admin) return;
    if (!user.active) return; // không chuyển sang tài khoản bị khóa
    _currentUser = user;
    notifyListeners();
  }
}
