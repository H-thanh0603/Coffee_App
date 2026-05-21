import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/ingredient.dart';
import '../../data/services/data_store.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    var list = List.of(store.ingredients);
    if (_filter == 'low') list = list.where((i) => i.isLow).toList();
    if (_filter == 'expiring') list = list.where((i) => i.isExpiringSoon || i.isExpired).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Kho nguyên liệu'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAdd(context, store)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            for (final f in const [['all','Tất cả'],['low','Sắp hết'],['expiring','Sắp hết hạn']])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f[1]),
                  selected: _filter == f[0],
                  onSelected: (_) => setState(() => _filter = f[0]),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _filter == f[0] ? Colors.white : AppColors.textPrimary),
                ),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(emoji: '📦', title: 'Không có nguyên liệu')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _IngTile(ing: list[i], store: store),
                ),
        ),
      ]),
    );
  }

  void _showAdd(BuildContext ctx, DataStore store) {
    showDialog(context: ctx, builder: (_) {
      final name = TextEditingController();
      final unit = TextEditingController(text: 'g');
      final stock = TextEditingController(text: '1000');
      final minS = TextEditingController(text: '500');
      return AlertDialog(
        title: const Text('Thêm nguyên liệu'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên')),
          TextField(controller: unit, decoration: const InputDecoration(labelText: 'Đơn vị')),
          TextField(controller: stock, decoration: const InputDecoration(labelText: 'Tồn'), keyboardType: TextInputType.number),
          TextField(controller: minS, decoration: const InputDecoration(labelText: 'Tồn tối thiểu'), keyboardType: TextInputType.number),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            if (name.text.trim().isEmpty) return;
            store.addIngredient(Ingredient(
              id: 'ing-' + DateTime.now().millisecondsSinceEpoch.toString(),
              name: name.text.trim(),
              unit: unit.text.trim(),
              currentStock: double.tryParse(stock.text) ?? 0,
              minStock: double.tryParse(minS.text) ?? 0,
              costPerUnit: 1,
            ));
            Navigator.pop(ctx);
          }, child: const Text('Thêm')),
        ],
      );
    });
  }
}

class _IngTile extends StatelessWidget {
  final Ingredient ing;
  final DataStore store;
  const _IngTile({required this.ing, required this.store});

  @override
  Widget build(BuildContext context) {
    final pct = ing.minStock > 0 ? (ing.currentStock / (ing.minStock * 2)).clamp(0.0, 1.0) : 1.0;
    Color color = AppColors.success;
    if (ing.isCritical) color = AppColors.danger;
    else if (ing.isLow) color = AppColors.warning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.inventory_2, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (ing.isExpiringSoon)
              const Text('⚠️ Sắp hết hạn', style: TextStyle(fontSize: 11, color: AppColors.warning)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(ing.currentStock.toStringAsFixed(0) + ' ' + ing.unit,
                style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16)),
            const SizedBox(width: 6),
            Text('/ tối thiểu ' + ing.minStock.toStringAsFixed(0) + ' ' + ing.unit,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showInOut(context, store, ing, isIn: true),
              icon: const Icon(Icons.add),
              label: const Text('Nhập'),
            ),
            TextButton.icon(
              onPressed: () => _showInOut(context, store, ing, isIn: false),
              icon: const Icon(Icons.remove),
              label: const Text('Xuất'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ]),
      ),
    );
  }

  void _showInOut(BuildContext ctx, DataStore store, Ingredient ing, {required bool isIn}) {
    final ctrl = TextEditingController(text: '100');
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(isIn ? 'Nhập kho' : 'Xuất kho'),
      content: TextField(controller: ctrl, decoration: InputDecoration(labelText: 'Số lượng (' + ing.unit + ')'), keyboardType: TextInputType.number),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
        ElevatedButton(onPressed: () {
          final qty = double.tryParse(ctrl.text) ?? 0;
          if (qty <= 0) return;
          if (isIn) {
            store.stockIn(ing.id, qty, 'Admin', note: 'Nhập thủ công');
          } else {
            store.stockOut(ing.id, qty, 'Admin', note: 'Xuất thủ công');
          }
          Navigator.pop(ctx);
        }, child: const Text('OK')),
      ],
    ));
  }
}
