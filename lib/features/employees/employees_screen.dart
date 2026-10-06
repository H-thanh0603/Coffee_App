import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/user.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final me = context.watch<AuthProvider>().currentUser;
    final list = store.users.where((u) => u.role != UserRole.customer).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Nhân viên'),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _addEdit(context, store, null)),
        ],
      ),
      body: Column(children: [
        if (me != null) _ShiftBar(userId: me.id, userName: me.fullName),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(emoji: '👥', title: 'Chưa có nhân viên')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final u = list[i];
                    final open = store.openShiftFor(u.id) != null;
                    return Card(
                      child: ListTile(
                        onTap: () => _addEdit(context, store, u),
                        leading: Stack(children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(u.fullName.characters.first,
                                style:
                                    const TextStyle(color: Colors.white)),
                          ),
                          if (open)
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 7,
                                backgroundColor: AppColors.success,
                              ),
                            ),
                        ]),
                        title: Text(u.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(u.role.label +
                            ' • ' +
                            u.email +
                            ' • ' +
                            u.phone +
                            (open ? '\n● Đang trong ca' : '')),
                        isThreeLine: open,
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Switch(
                            value: u.active,
                            activeColor: AppColors.primary,
                            onChanged: (val) =>
                                store.updateUser(u.copyWith(active: val)),
                          ),
                          PopupMenuButton<String>(
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Sửa')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Xóa')),
                            ],
                            onSelected: (val) {
                              if (val == 'edit') {
                                _addEdit(context, store, u);
                              } else if (val == 'delete') {
                                store.removeUser(u.id);
                              }
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _addEdit(BuildContext ctx, DataStore store, AppUser? u) {
    final name = TextEditingController(text: u?.fullName ?? '');
    final email = TextEditingController(text: u?.email ?? '');
    final phone = TextEditingController(text: u?.phone ?? '');
    UserRole role = u?.role ?? UserRole.cashier;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text(u == null ? 'Thêm nhân viên' : 'Sửa nhân viên'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name,
                  decoration: const InputDecoration(labelText: 'Họ tên')),
              TextField(controller: email,
                  decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: phone,
                  decoration: const InputDecoration(labelText: 'SĐT')),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: UserRole.values
                    .where((r) => r != UserRole.customer)
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (v) => setSt(() => role = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                  return;
                }
                if (u == null) {
                  store.addUser(AppUser(
                    id: const Uuid().v4(),
                    fullName: name.text.trim(),
                    email: email.text.trim().toLowerCase(),
                    phone: phone.text.trim(),
                    role: role,
                  ));
                } else {
                  store.updateUser(u.copyWith(
                    fullName: name.text.trim(),
                    email: email.text.trim().toLowerCase(),
                    phone: phone.text.trim(),
                    role: role,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh vào/ra ca của chính người đang đăng nhập.
/// Chấm công gán đơn theo ca: báo cáo theo NV hết lệch khi dùng chung máy.
class _ShiftBar extends StatelessWidget {
  final String userId;
  final String userName;
  const _ShiftBar({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final open = store.openShiftFor(userId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        color: open == null
            ? AppColors.cardBg
            : AppColors.success.withOpacity(0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(
                open == null
                    ? Icons.login
                    : Icons.timelapse,
                color: open == null ? AppColors.primary : AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        open == null
                            ? 'Bạn chưa vào ca'
                            : 'Đang trong ca từ ' +
                                Fmt.time(open.clockIn) +
                                ' • ' +
                                Fmt.money(store.revenueInShift(open)),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (open == null)
                      Text('Vào ca để đơn bán ra gán đúng người',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                  ]),
            ),
            ElevatedButton(
              onPressed: () {
                if (open == null) {
                  store.clockIn(userId, userName);
                } else {
                  final worked = store.clockOut(userId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Ra ca • làm ' +
                            worked.inHours.toString() +
                            'h' +
                            (worked.inMinutes % 60).toString().padLeft(2, '0') +
                            ' • ' +
                            Fmt.money(store.paidOrders
                                .where((o) =>
                                    o.cashierName == userName &&
                                    o.paidAt.isAfter(open.clockIn))
                                .fold<double>(
                                    0, (s, o) => s + o.total)))),
                  );
                }
              },
              style: open == null
                  ? null
                  : ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger),
              child: Text(open == null ? 'Vào ca' : 'Ra ca'),
            ),
          ]),
        ),
      ),
    );
  }
}
