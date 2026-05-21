import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/product.dart';
import '../../data/services/data_store.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _q = '';
  String? _catId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final products = store.products.where((p) {
      if (_catId != null && p.categoryId != _catId) return false;
      if (_q.isNotEmpty && !p.name.toLowerCase().contains(_q.toLowerCase())) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Menu sản phẩm'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _addEdit(context, store, null)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Tìm món', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child:
                ChoiceChip(label: const Text('Tất cả'), selected: _catId == null,
                  onSelected: (_) => setState(() => _catId = null),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _catId == null ? Colors.white : AppColors.textPrimary)),
              ),
              ...store.categories.map((c) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  avatar: Text(c.icon),
                  label: Text(c.name),
                  selected: _catId == c.id,
                  onSelected: (_) => setState(() => _catId = c.id),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _catId == c.id ? Colors.white : AppColors.textPrimary),
                ),
              )),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const EmptyState(emoji: '🍴', title: 'Không có món nào')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _addEdit(context, store, p),
                        leading: Text(p.emoji, style: const TextStyle(fontSize: 32)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(Fmt.money(p.basePrice) + (p.hidden ? ' • Đã ẩn' : '') + (!p.inStock ? ' • Hết hàng' : '')),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'toggle_stock', child: Text('Toggle hết hàng')),
                            PopupMenuItem(value: 'toggle_hide', child: Text('Toggle ẩn')),
                            PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          ],
                          onSelected: (v) {
                            if (v == 'toggle_stock') {
                              store.updateProduct(p.copyWith(inStock: !p.inStock));
                            } else if (v == 'toggle_hide') {
                              store.updateProduct(p.copyWith(hidden: !p.hidden));
                            } else if (v == 'delete') {
                              store.removeProduct(p.id);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  void _addEdit(BuildContext ctx, DataStore store, Product? p) {
    final name = TextEditingController(text: p?.name ?? '');
    final desc = TextEditingController(text: p?.description ?? '');
    final price = TextEditingController(text: (p?.basePrice ?? 30000).toStringAsFixed(0));
    final emoji = TextEditingController(text: p?.emoji ?? '☕');
    String catId = p?.categoryId ?? store.categories.first.id;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (_, setSt) => AlertDialog(
        title: Text(p == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Mô tả')),
          TextField(controller: price, decoration: const InputDecoration(labelText: 'Giá cơ bản'), keyboardType: TextInputType.number),
          TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji / icon')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: catId,
            decoration: const InputDecoration(labelText: 'Danh mục'),
            items: store.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setSt(() => catId = v!),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            final priceVal = double.tryParse(price.text) ?? 30000;
            if (p == null) {
              store.addProduct(Product(
                id: 'p-' + const Uuid().v4(),
                name: name.text.trim(),
                description: desc.text.trim(),
                emoji: emoji.text.trim().isEmpty ? '☕' : emoji.text.trim(),
                categoryId: catId,
                basePrice: priceVal,
              ));
            } else {
              store.updateProduct(p.copyWith(
                name: name.text.trim(),
                description: desc.text.trim(),
                emoji: emoji.text.trim(),
                categoryId: catId,
                basePrice: priceVal,
              ));
            }
            Navigator.pop(ctx);
          }, child: const Text('Lưu')),
        ],
      ),
    ));
  }
}
