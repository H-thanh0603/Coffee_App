import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart' as sb;

import '../../core/constants/enums.dart';
import '../../data/models/user.dart';
import '../../data/services/data_store.dart';

class AuthProvider extends ChangeNotifier {
  final DataStore _store;
  final sb.SupabaseClient? _client;

  AppUser? _currentUser;
  bool _restored = false;

  AuthProvider(this._store, {sb.SupabaseClient? client})
      : _client = client ?? _store.repo.client;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;

  /// Đã chạy restoreSession chưa (chặn redirect splash tới khi xong).
  bool get restored => _restored;

  bool get _remote => _client != null;

  /// Đăng nhập. Có Supabase client → signInWithPassword + fetch profile.
  /// Không có (offline/demo) → fallback mock password '123456'.
  Future<String?> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();

    if (_remote) {
      try {
        await _client!.auth.signInWithPassword(
          email: normalized,
          password: password,
        );
        final appUser = await _fetchProfile(normalized);
        if (appUser == null || !appUser.active) {
          await _client!.auth.signOut();
          return appUser == null
              ? 'Tài khoản chưa có hồ sơ'
              : 'Tài khoản đã bị khóa';
        }
        _currentUser = appUser;
        notifyListeners();
        // Kéo catalog + data từ server thay cache local
        await _store.refreshFromServer();
        return null;
      } on sb.AuthException catch (e) {
        return _friendlyAuthError(e.message);
      } catch (e) {
        debugPrint('login error: $e');
        return 'Không kết nối được máy chủ';
      }
    }

    // ==== Mock demo (không có backend) ====
    if (password != '123456') return 'Mật khẩu không đúng (demo: 123456)';
    final user = _store.findUserByEmail(normalized);
    if (user == null) return 'Email không tồn tại';
    if (!user.active) return 'Tài khoản đã bị khóa';
    _currentUser = user;
    notifyListeners();
    return null;
  }

  /// Phục hồi session cũ khi mở lại app (auth.currentSession).
  Future<void> restoreSession() async {
    final c = _client;
    if (c != null) {
      final email = c.auth.currentSession?.user.email;
      if (email != null) {
        final appUser = await _fetchProfile(email);
        if (appUser != null && appUser.active) {
          _currentUser = appUser;
        } else {
          await c.auth.signOut();
          _currentUser = null;
        }
      } else {
        _currentUser = null;
      }
    } else {
      _currentUser = null;
    }
    _restored = true;
    notifyListeners();
  }

  /// Đăng xuất. Có remote → signOut session; giữ mirror local.
  Future<void> logout() async {
    if (_remote) {
      try {
        await _client!.auth.signOut();
      } catch (e) {
        debugPrint('logout error: $e');
      }
    }
    _currentUser = null;
    notifyListeners();
  }

  void switchAccount(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Fetch AppUser từ profiles theo email (snake_row → AppUser).
  Future<AppUser?> _fetchProfile(String email) async {
    try {
      final r = await _client!
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();
      if (r == null) return null;
      final m = _camel(Map<String, dynamic>.from(r));
      final role = UserRole.values.firstWhere(
        (e) => e.name == m['role'],
        orElse: () => UserRole.admin,
      );
      return AppUser(
        id: m['id'] as String,
        fullName: m['fullName'] as String? ?? '',
        email: m['email'] as String,
        phone: m['phone'] as String? ?? '',
        role: role,
        avatarUrl: m['avatarUrl'] as String?,
        active: m['active'] as bool? ?? true,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? ''),
      );
    } catch (e) {
      debugPrint('fetchProfile error: $e');
      return null;
    }
  }

  Map<String, dynamic> _camel(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      final parts = k.split('_');
      out[parts.first +
          parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join()] =
          v;
    });
    return out;
  }

  String _friendlyAuthError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không đúng';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email chưa xác nhận';
    }
    if (lower.contains('rate limit')) return 'Thử lại sau ít phút';
    if (lower.contains('user already registered')) return 'Email đã tồn tại';
    return raw;
  }
}