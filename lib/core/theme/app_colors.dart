import 'package:flutter/material.dart';

/// Bảng màu chủ đạo SmartCafe - tông nâu cafe / kem / cam ấm
class AppColors {
  AppColors._();

  // Primary - Nâu cafe đậm
  static const Color primary = Color(0xFF6F4E37);
  static const Color primaryLight = Color(0xFF8D6E5C);
  static const Color primaryDark = Color(0xFF4A2C20);

  // Secondary - Cam đất ấm
  static const Color secondary = Color(0xFFD4A574);
  static const Color secondaryLight = Color(0xFFE8C9A7);

  // Accent - Cam nhạt
  static const Color accent = Color(0xFFF59E0B);

  // Background - Kem
  static const Color background = Color(0xFFFAF6F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFBF6);

  // Text
  static const Color textPrimary = Color(0xFF2C1810);
  static const Color textSecondary = Color(0xFF6B5447);
  static const Color textHint = Color(0xFF9C8676);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Order status colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusPreparing = Color(0xFF3B82F6);
  static const Color statusReady = Color(0xFF8B5CF6);
  static const Color statusServed = Color(0xFF22C55E);
  static const Color statusPaid = Color(0xFF10B981);
  static const Color statusCancelled = Color(0xFF94A3B8);

  // Table status
  static const Color tableEmpty = Color(0xFF94A3B8);
  static const Color tableServing = Color(0xFF3B82F6);
  static const Color tableWaiting = Color(0xFFF59E0B);
  static const Color tableReserved = Color(0xFF8B5CF6);
  static const Color tableNeedsClean = Color(0xFFEF4444);

  // Border
  static const Color border = Color(0xFFE7DDD0);
  static const Color divider = Color(0xFFEFE6D9);
}
