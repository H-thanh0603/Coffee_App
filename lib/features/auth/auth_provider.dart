import 'package:flutter/foundation.dart';

import '../../core/constants/enums.dart';
import '../../data/models/user.dart';
import '../../data/services/data_store.dart';

class AuthProvider extends ChangeNotifier {
  final DataStore _store;
  AppUser? _currentUser;

  AuthProvider(this._store);

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;

  String? login(String email, String password) {
    // Mock auth: tất cả tài khoản demo đều dùng password "123456"
    if (password != '123456') return 'Mật khẩu không đúng (demo: 123456)';
    final user = _store.findUserByEmail(email.trim().toLowerCase());
    if (user == null) return 'Email không tồn tại';
    if (!user.active) return 'Tài khoản đã bị khóa';
    _currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  void switchAccount(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }
}
