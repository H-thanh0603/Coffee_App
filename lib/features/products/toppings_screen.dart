import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/topping.dart';
import '../../data/services/data_store.dart';

class ToppingsScreen extends StatelessWidget {
  const ToppingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Topping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addEdit(context, store, null),
          ),
        ],
      ),
      body: store.toppings.isEmpty
          ? const EmptyState(emoji: '🧋', title: 'Chưa có topping')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: store.toppings.length,
              itemBuilder: (_, i) {
                final t = store.toppings[i];
                return Card(
                  child: ListTile(
                    onTap: () => _addEdit(context, store, t),
                    leading: CircleAvatar(
                      backgroundColor: t.available
                          ? AppColors.primary
                          : AppColors.border,
                      child: const Icon(Icons.icecream, color: Colors.white),
                    ),
                    title: Text(t.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(Fmt.money(t.price) +
                        (t.available ? '' : ' • Đã hết')),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'toggle',
                            child: Text(t.available ? 'Đánh dấu hết' : 'Còn hàng')),
                        const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                      onSelected: (v) {
                        if (v == 'toggle') {
                          store.updateTopping(
                              t.copyWith(available: !t.available));
                        } else if (v == 'delete') {
                          store.removeTopping(t.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _addEdit(BuildContext ctx, DataStore store, Topping? t) {
    final name = TextEditingController(text: t?.name ?? '');
    final price = TextEditingController(
        text: (t?.price ?? 5000).toStringAsFixed(0));
    var available = t?.available ?? true;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text(t == null ? 'Thêm topping' : 'Sửa topping'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name,
                  decoration: const InputDecoration(labelText: 'Tên topping')),
              TextField(
                controller: price,
                decoration: const InputDecoration(labelText: 'Giá'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: const Text('Còn hàng'),
                value: available,
                onChanged: (v) => setSt(() => available = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                final priceVal = double.tryParse(price.text) ?? 0;
                if (t == null) {
                  store.addTopping(Topping(
                    id: 'top-' + const Uuid().v4(),
                    name: name.text.trim(),
                    price: priceVal,
                    available: available,
                  ));
                } else {
                  store.updateTopping(t.copyWith(
                    name: name.text.trim(),
                    price: priceVal,
                    available: available,
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
