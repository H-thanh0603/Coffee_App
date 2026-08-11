import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/auth_provider.dart';
import '../constants/enums.dart';
import '../theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.currentUser;
    if (u == null) return const SizedBox();

    final items = <_NavItem>[];
    if (u.role == UserRole.admin) {
      items.addAll([
        _NavItem(Icons.dashboard, 'Dashboard', '/admin'),
        _NavItem(Icons.local_cafe, 'Menu sản phẩm', '/products'),
        _NavItem(Icons.category, 'Danh mục', '/categories'),
        _NavItem(Icons.icecream, 'Topping', '/toppings'),
        _NavItem(Icons.point_of_sale, 'Bán hàng POS', '/cashier'),
        _NavItem(Icons.receipt_long, 'Đơn hàng', '/orders'),
        _NavItem(Icons.table_restaurant, 'Bàn', '/tables'),
        _NavItem(Icons.inventory_2, 'Kho nguyên liệu', '/inventory'),
        _NavItem(Icons.book_outlined, 'Công thức', '/recipes'),
        _NavItem(Icons.people_alt, 'Khách hàng', '/customers'),
        _NavItem(Icons.discount, 'Voucher', '/vouchers'),
        _NavItem(Icons.bar_chart, 'Báo cáo', '/reports'),
        _NavItem(Icons.badge, 'Nhân viên', '/employees'),
      ]);
    } else if (u.role == UserRole.cashier) {
      items.addAll([
        _NavItem(Icons.point_of_sale, 'Bán hàng POS', '/cashier'),
        _NavItem(Icons.receipt_long, 'Đơn hàng', '/orders'),
        _NavItem(Icons.table_restaurant, 'Bàn', '/tables'),
        _NavItem(Icons.people_alt, 'Khách hàng', '/customers'),
      ]);
    } else if (u.role == UserRole.barista) {
      items.add(_NavItem(Icons.coffee_maker, 'Pha chế', '/barista'));
    } else if (u.role == UserRole.waiter) {
      items.addAll([
        _NavItem(Icons.point_of_sale, 'Bán hàng', '/cashier'),
        _NavItem(Icons.table_restaurant, 'Bàn', '/waiter'),
        _NavItem(Icons.receipt_long, 'Đơn hàng', '/orders'),
      ]);
    } else {
      items.add(_NavItem(Icons.local_cafe, 'Menu', '/customer'));
    }
    items.add(_NavItem(Icons.settings, 'Cài đặt', '/settings'));
    items.add(_NavItem(Icons.person_outline, 'Hồ sơ', '/profile'));

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(u.fullName.characters.first,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Text(u.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(u.role.label,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: items
                  .map((it) => ListTile(
                        leading: Icon(it.icon, color: AppColors.textPrimary),
                        title: Text(it.label),
                        onTap: () {
                          Navigator.pop(context);
                          context.go(it.route);
                        },
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Đăng xuất',
                style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pop(context);
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  _NavItem(this.icon, this.label, this.route);
}
