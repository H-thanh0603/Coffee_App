import 'package:flutter/material.dart';

/// Bảng màu chủ đạo SmartCafe - tông nâu cafe / kem / cam ấm.
/// Màu "bề mặt" (background/surface/cardBg/text/border) tự động đổi theo
/// [dark] (light/dark mode). Màu brand/status giữ nguyên ở cả 2 theme.
class AppColors {
  AppColors._();

  /// Bật dark palette. Được set bởi ThemeProvider trước khi build UI.
  static bool dark = false;

  // Primary - Nâu cafe đậm
  static const Color primary = Color(0xFF6F4E37);
  static const Color primaryLight = Color(0xFF8D6E5C);
  static const Color primaryDark = Color(0xFF4A2C20);

  // Secondary - Cam đất ấm
  static const Color secondary = Color(0xFFD4A574);
  static const Color secondaryLight = Color(0xFFE8C9A7);

  // Accent - Cam nhạt
  static const Color accent = Color(0xFFF59E0B);

  // Background - Kem (light) / Nâu than (dark)
  static Color get background => dark ? const Color(0xFF17110C) : const Color(0xFFFAF6F1);
  static Color get surface => dark ? const Color(0xFF211A13) : const Color(0xFFFFFFFF);
  static Color get cardBg => dark ? const Color(0xFF2A2119) : const Color(0xFFFFFBF6);

  // Text
  static Color get textPrimary => dark ? const Color(0xFFF3E9DF) : const Color(0xFF2C1810);
  static Color get textSecondary => dark ? const Color(0xFFC4AE9C) : const Color(0xFF6B5447);
  static Color get textHint => dark ? const Color(0xFF8A7563) : const Color(0xFF9C8676);

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
  static Color get border => dark ? const Color(0xFF4A3B2E) : const Color(0xFFE7DDD0);
  static Color get divider => dark ? const Color(0xFF3A2E24) : const Color(0xFFEFE6D9);
}
