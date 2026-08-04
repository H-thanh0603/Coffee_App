import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/recipe.dart';
import '../../data/services/data_store.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final recipes = store.recipes;

    // Sản phẩm chưa có bất kỳ công thức nào (size nào)
    final missing = store.products
        .where((p) => !recipes.any((r) => r.productId == p.id))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Công thức pha chế'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addEdit(context, store, null),
          ),
        ],
      ),
      body: recipes.isEmpty && missing.isEmpty
          ? const EmptyState(emoji: '📖', title: 'Chưa có công thức')
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (missing.isNotEmpty) ...[
                  const Text('⚠️ Sản phẩm chưa có công thức',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ...missing.take(6).map((p) => Card(
                        child: ListTile(
                          leading:
                              Text(p.emoji, style: const TextStyle(fontSize: 26)),
                          title: Text(p.name),
                          subtitle: const Text('Chưa có công thức - không trừ kho được',
                              style: TextStyle(fontSize: 11, color: AppColors.warning)),
                          trailing: TextButton.icon(
                            onPressed: () => _addEdit(context, store, null,
                                presetProductId: p.id),
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm'),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                ...recipes.map((r) => _RecipeCard(
                      recipe: r,
                      onEdit: () => _addEdit(context, store, r),
                      onDelete: () => store.removeRecipe(r.id),
                    )),
              ],
            ),
    );
  }

  void _addEdit(BuildContext ctx, DataStore store, Recipe? r,
      {String? presetProductId}) {
    if (store.products.isEmpty || store.ingredients.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Cần có sản phẩm và nguyên liệu')),
      );
      return;
    }
    String productId = r?.productId ?? presetProductId ?? store.products.first.id;
    DrinkSize size = r?.size ?? DrinkSize.m;

    // Controller cho từng nguyên liệu
    final ctrls = <String, TextEditingController>{};
    for (final ing in store.ingredients) {
      final qty = r == null
          ? 0.0
          : (r.items.firstWhere((it) => it.ingredientId == ing.id,
                  orElse: () => RecipeItem(
                      ingredientId: ing.id, quantity: 0, unit: ing.unit)))
              .quantity;
      ctrls[ing.id] = TextEditingController(text: qty.toStringAsFixed(0));
    }

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text(r == null ? 'Thêm công thức' : 'Sửa công thức'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: productId,
                decoration: const InputDecoration(labelText: 'Sản phẩm'),
                items: store.products
                    .map((p) => DropdownMenuItem(
                        value: p.id, child: Text(p.emoji + ' ' + p.name)))
                    .toList(),
                onChanged: (v) => setSt(() => productId = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DrinkSize>(
                initialValue: size,
                decoration: const InputDecoration(labelText: 'Size'),
                items: DrinkSize.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.code)))
                    .toList(),
                onChanged: (v) => setSt(() => size = v!),
              ),
              const SizedBox(height: 12),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Nguyên liệu (định lượng)',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 4),
              ...store.ingredients.map((ing) => Row(children: [
                    Expanded(
                        child: Text(ing.name + ' (' + ing.unit + ')',
                            style: const TextStyle(fontSize: 13))),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: ctrls[ing.id],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                  ])),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                final items = <RecipeItem>[];
                for (final ing in store.ingredients) {
                  final qty = double.tryParse(ctrls[ing.id]!.text) ?? 0;
                  if (qty > 0) {
                    items.add(RecipeItem(
                        ingredientId: ing.id, quantity: qty, unit: ing.unit));
                  }
                }
                if (items.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Cần định lượng ít nhất 1 nguyên liệu')),
                  );
                  return;
                }
                if (r == null) {
                  store.addRecipe(Recipe(
                    id: const Uuid().v4(),
                    productId: productId,
                    size: size,
                    items: items,
                  ));
                } else {
                  store.updateRecipe(Recipe(
                    id: r.id,
                    productId: productId,
                    size: size,
                    items: items,
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

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RecipeCard(
      {required this.recipe, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final p = store.products.cast<dynamic>().firstWhere(
        (e) => e.id == recipe.productId,
        orElse: () => null);
    if (p == null) return const SizedBox.shrink();
    final cost = recipe.items.fold<double>(0, (s, it) {
      final ing = store.findIngredient(it.ingredientId);
      return s + (ing?.costPerUnit ?? 0) * it.quantity;
    });
    final price = p.priceFor(recipe.size);
    final profit = price - cost;
    return Card(
      child: ExpansionTile(
        leading: Text(p.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(p.name + ' (' + recipe.size.code + ')',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Giá vốn: ' + Fmt.money(cost) + ' • Lãi: ' + Fmt.money(profit),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        ),
        children: recipe.items
            .map((it) {
              final ing = store.findIngredient(it.ingredientId);
              return ListTile(
                dense: true,
                leading: const Icon(Icons.local_grocery_store, size: 18),
                title: Text(ing?.name ?? it.ingredientId),
                trailing: Text(
                    it.quantity.toStringAsFixed(0) + ' ' + it.unit,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            })
            .toList(),
      ),
    );
  }
}
