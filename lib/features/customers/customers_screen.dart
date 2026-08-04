import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/customer.dart';
import '../../data/services/data_store.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    var list = store.customers
        .where((c) =>
            _q.isEmpty ||
            c.fullName.toLowerCase().contains(_q.toLowerCase()) ||
            c.phone.contains(_q))
        .toList();
    list.sort((a, b) => b.points.compareTo(a.points));
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Khách hàng'),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _add(context, store)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Tìm theo tên/SĐT',
                prefixIcon: Icon(Icons.search),
                isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(emoji: '🙋', title: 'Không có khách hàng')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.go('/customers/' + c.id),
                        leading: CircleAvatar(
                          backgroundColor: Color(c.rank.colorValue),
                          child: Text(c.fullName.characters.first,
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Row(children: [
                          Expanded(
                              child: Text(c.fullName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(c.rank.colorValue).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(c.rank.label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(c.rank.colorValue),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        subtitle: Text(c.phone +
                            ' • ' +
                            c.points.toString() +
                            ' điểm • ' +
                            Fmt.money(c.totalSpent)),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _add(BuildContext ctx, DataStore store) {
    final name = TextEditingController(),
        phone = TextEditingController(),
        email = TextEditingController();
    showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
              title: const Text('Thêm khách hàng'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Họ tên')),
                TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'SĐT')),
                TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy')),
                ElevatedButton(
                    onPressed: () {
                      if (name.text.trim().isEmpty ||
                          phone.text.trim().isEmpty) {
                        return;
                      }
                      store.addCustomer(Customer(
                        id: const Uuid().v4(),
                        fullName: name.text.trim(),
                        phone: phone.text.trim(),
                        email: email.text.trim(),
                      ));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Thêm')),
              ],
            ));
  }
}
