import '../../core/constants/enums.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final UserRole? targetRole;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.targetRole,
    this.isRead = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
