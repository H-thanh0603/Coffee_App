import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'routes/app_router.dart';

class SmartCafeApp extends StatelessWidget {
  const SmartCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final router = AppRouter.create(auth);
        return MaterialApp.router(
          title: 'SmartCafe',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
        );
      },
    );
  }
}
