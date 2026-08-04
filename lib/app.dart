import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
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
            );
          },
        );
      },
    );
  }
}
