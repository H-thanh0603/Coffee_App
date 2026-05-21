import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/user.dart';
import '../../data/services/data_store.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final list = store.users.where((u) => u.role != UserRole.customer).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Nhân viên'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: () => _add(context, store)),
        ],
      ),
      body: list.isEmpty
          ? const EmptyState(emoji: '👥', title: 'Chưa có nhân viên')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final u = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(u.fullName.characters.first, style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(u.role.label + ' • ' + u.email + ' • ' + u.phone),
                    trailing: Switch(
                      value: u.active,
                      activeColor: AppColors.primary,
                      onChanged: (v) => store.updateUser(u.copyWith(active: v)),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _add(BuildContext ctx, DataStore store) {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    UserRole role = UserRole.cashier;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (_, setSt) => AlertDialog(
        title: const Text('Thêm nhân viên'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên')),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'SĐT')),
          const SizedBox(height: 8),
          DropdownButtonFormField<UserRole>(
            value: role,
            decoration: const InputDecoration(labelText: 'Vai trò'),
            items: UserRole.values.where((r) => r != UserRole.customer)
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
            onChanged: (v) => setSt(() => role = v!),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            if (name.text.trim().isEmpty || email.text.trim().isEmpty) return;
            store.addUser(AppUser(
              id: const Uuid().v4(),
              fullName: name.text.trim(),
              email: email.text.trim().toLowerCase(),
              phone: phone.text.trim(),
              role: role,
            ));
            Navigator.pop(ctx);
          }, child: const Text('Thêm')),
        ],
      ),
    ));
  }
}
