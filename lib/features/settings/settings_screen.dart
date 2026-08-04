import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_drawer.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Chế độ giao diện',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            for (final m in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: m,
                groupValue: tp.mode,
                title: Text(_label(m)),
                subtitle: m == ThemeMode.system
                    ? const Text('Tự động theo cài đặt máy')
                    : null,
                secondary: Icon(_icon(m), color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                activeColor: AppColors.primary,
                onChanged: (v) {
                  if (v != null) tp.setMode(v);
                },
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.primary),
            title: const Text('SmartCafe'),
            subtitle: const Text('Hệ thống quản lý bán cafe thông minh'),
          ),
        ),
      ]),
    );
  }

  String _label(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 'Theo hệ thống';
      case ThemeMode.light:
        return 'Sáng (Light)';
      case ThemeMode.dark:
        return 'Tối (Dark)';
    }
  }

  IconData _icon(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}