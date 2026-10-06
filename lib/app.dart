import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'data/services/data_store.dart';
import 'features/auth/auth_provider.dart';
import 'routes/app_router.dart';

class SmartCafeApp extends StatelessWidget {
  const SmartCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            // Đồng bộ AppColors với chế độ hiện tại trước khi build UI
            final brightness = MediaQuery.platformBrightnessOf(context);
            final isDark = themeProvider.mode == ThemeMode.dark ||
                (themeProvider.mode == ThemeMode.system &&
                    brightness == Brightness.dark);
            AppColors.dark = isDark;

            final router = AppRouter.create(auth);
            return MaterialApp.router(
              title: 'SmartCafe',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.mode,
              routerConfig: router,
              // Banner cảnh báo khi có op không đồng bộ được lên server
              builder: (context, child) => Column(children: [
                const _SyncErrorBanner(),
                Expanded(child: child ?? const SizedBox.shrink()),
              ]),
            );
          },
        );
      },
    );
  }
}

class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner();

  @override
  Widget build(BuildContext context) {
    return Consumer<DataStore>(
      builder: (context, store, _) {
        final error = store.syncError;
        if (error == null) return const SizedBox.shrink();
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: AppColors.danger,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.cloud_off, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: store.retryFailedSync,
                    child: const Text('Thử lại',
                        style: TextStyle(color: Colors.white)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                    // Chỉ tạm ẩn banner; op vẫn nằm trong dead-letter
                    onPressed: store.dismissSyncError,
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
