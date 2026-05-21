import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/services/data_store.dart';

class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final recipes = store.recipes;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Công thức pha chế')),
      body: recipes.isEmpty
          ? const EmptyState(emoji: '📖', title: 'Chưa có công thức')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: recipes.length,
              itemBuilder: (_, i) {
                final r = recipes[i];
                final p = store.products.cast<dynamic>().firstWhere(
                    (e) => e.id == r.productId, orElse: () => null);
                if (p == null) return const SizedBox();
                final cost = r.items.fold<double>(0, (s, it) {
                  final ing = store.findIngredient(it.ingredientId);
                  return s + (ing?.costPerUnit ?? 0) * it.quantity;
                });
                final price = p.priceFor(r.size);
                final profit = price - cost;
                return Card(
                  child: ExpansionTile(
                    leading: Text(p.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(p.name + ' (' + r.size.code + ')',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Giá vốn: ' + Fmt.money(cost) +
                        ' • Lãi: ' + Fmt.money(profit),
                        style: const TextStyle(fontSize: 12)),
                    children: r.items.map((it) {
                      final ing = store.findIngredient(it.ingredientId);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.local_grocery_store, size: 18),
                        title: Text(ing?.name ?? it.ingredientId),
                        trailing: Text(it.quantity.toStringAsFixed(0) + ' ' + it.unit,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
