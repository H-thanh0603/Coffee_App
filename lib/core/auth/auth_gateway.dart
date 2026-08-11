import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/enums.dart';
import '../../data/models/user.dart';
import '../../data/services/data_store.dart';

/// Seam giữa AuthProvider và nguồn xác thực (Supabase thật hoặc fake local).
/// Fake giữ các test hiện tại chạy offline; Supabase là backend thật.
abstract class AuthGateway {
  /// Đăng nhập. Trả về null nếu thành công, ngược lại chuỗi lỗi (tiếng Việt).
  Future<String?> signIn(String email, String password);

  Future<void> signOut();

  /// Lấy thông tin AppUser của user đang đăng nhập; null nếu chưa login.
  Future<AppUser?> currentUser();

  /// Khôi phục session khi mở app (splash). Không throw khi offline.
  Future<AppUser?> restoreSession();
}

/// Backend thật: Supabase Auth (email/password) + app_users row (RLS).
class AuthGatewaySupabase implements AuthGateway {
  AuthGatewaySupabase(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException {
      return 'Email hoặc mật khẩu không đúng';
    }
    final user = await currentUser();
    if (user == null) return 'Tài khoản không tồn tại trên hệ thống';
    if (!user.active) {
      await _client.auth.signOut();
      return 'Tài khoản đã bị khóa';
    }
    return null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<AppUser?> currentUser() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return _fetchAppUser(id);
  }

  @override
  Future<AppUser?> restoreSession() async {
    // INITIAL_SESSION đã được khôi phục bởi supabase_flutter khi khởi động.
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    return _fetchAppUser(id);
  }

  Future<AppUser?> _fetchAppUser(String id) async {
    try {
      final rows =
          await _client.from('app_users').select().eq('id', id).limit(1);
      if (rows.isEmpty) return null;
      final r = Map<String, dynamic>.from(rows.first);
      return AppUser(
        id: r['id'] as String,
        fullName: r['full_name'] as String? ?? '',
        email: r['email'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        role: _role(r['role'] as String?),
        active: r['active'] as bool? ?? true,
      );
    } catch (_) {
      return null; // offline -> không login được
    }
  }

  UserRole _role(String? code) => UserRole.fromCode(code ?? 'customer');
}

/// Fake local (test / offline): xác thực bằng DataStore seed users.
class AuthGatewayFake implements AuthGateway {
  AuthGatewayFake(this._store);

  final DataStore _store;

  @override
  Future<String?> signIn(String email, String password) async {
    final user = _store.findUserByEmail(email.trim().toLowerCase());
    if (password != '123456') return 'Mật khẩu không đúng (demo: 123456)';
    if (user == null) return 'Email không tồn tại';
    if (!user.active) return 'Tài khoản đã bị khóa';
    _current = user;
    return null;
  }

  AppUser? _current;

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<AppUser?> currentUser() async => _current;

  @override
  Future<AppUser?> restoreSession() async => _current;
}
