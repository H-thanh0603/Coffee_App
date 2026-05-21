import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.currentUser;
    if (u == null) return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary,
            child: Text(u.fullName.characters.first,
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(u.fullName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
        Center(child: Text(u.role.label,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
        const SizedBox(height: 24),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text(u.email)),
          ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('SĐT'), subtitle: Text(u.phone)),
          ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Vai trò'), subtitle: Text(u.role.label)),
        ])),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            auth.logout();
            context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ]),
    );
  }
}
