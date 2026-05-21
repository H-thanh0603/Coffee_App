import '../../core/constants/enums.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final bool active;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.active = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AppUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    bool? active,
  }) =>
      AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        active: active ?? this.active,
        createdAt: createdAt,
      );
}
