import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/category.dart';
import '../../data/services/data_store.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Danh mục món'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addEdit(context, store, null),
          ),
        ],
      ),
      body: store.categories.isEmpty
          ? const EmptyState(emoji: '🗂️', title: 'Chưa có danh mục')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: store.categories.length,
              itemBuilder: (_, i) {
                final c = store.categories[i];
                return Card(
                  child: ListTile(
                    onTap: () => _addEdit(context, store, c),
                    leading: Text(c.icon, style: const TextStyle(fontSize: 30)),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(c.description.isEmpty
                        ? (c.active ? 'Đang hiển thị' : 'Đã tắt')
                        : c.description),
                    trailing: PopupMenuButton<String>(
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'toggle', child: Text(c.active ? 'Tắt' : 'Bật')),
                        const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                      onSelected: (v) {
                        if (v == 'toggle') {
                          store.updateCategory(ProductCategory(
                            id: c.id,
                            name: c.name,
                            description: c.description,
                            icon: c.icon,
                            active: !c.active,
                          ));
                        } else if (v == 'delete') {
                          store.removeCategory(c.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _addEdit(BuildContext ctx, DataStore store, ProductCategory? c) {
    final name = TextEditingController(text: c?.name ?? '');
    final desc = TextEditingController(text: c?.description ?? '');
    final icon = TextEditingController(text: c?.icon ?? '☕');
    var active = c?.active ?? true;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text(c == null ? 'Thêm danh mục' : 'Sửa danh mục'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name,
                  decoration: const InputDecoration(labelText: 'Tên danh mục')),
              TextField(controller: desc,
                  decoration: const InputDecoration(labelText: 'Mô tả')),
              TextField(controller: icon,
                  decoration: const InputDecoration(labelText: 'Icon / emoji')),
              SwitchListTile(
                title: const Text('Đang hiển thị'),
                value: active,
                onChanged: (v) => setSt(() => active = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                if (c == null) {
                  store.addCategory(ProductCategory(
                    id: 'cat-' + const Uuid().v4(),
                    name: name.text.trim(),
                    description: desc.text.trim(),
                    icon: icon.text.trim().isEmpty ? '☕' : icon.text.trim(),
                    active: active,
                  ));
                } else {
                  store.updateCategory(ProductCategory(
                    id: c.id,
                    name: name.text.trim(),
                    description: desc.text.trim(),
                    icon: icon.text.trim().isEmpty ? c.icon : icon.text.trim(),
                    active: active,
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
