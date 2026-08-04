import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/cafe_table.dart';
import '../../data/services/data_store.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final tables = store.tables;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Sơ đồ bàn')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in TableStatus.values) StatusBadge.table(s),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: tables.length,
              itemBuilder: (_, i) => _TableCard(table: tables[i], store: store),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final CafeTable table;
  final DataStore store;
  const _TableCard({required this.table, required this.store});

  Color get _color {
    switch (table.status) {
      case TableStatus.empty: return AppColors.tableEmpty;
      case TableStatus.serving: return AppColors.tableServing;
      case TableStatus.waiting: return AppColors.tableWaiting;
      case TableStatus.reserved: return AppColors.tableReserved;
      case TableStatus.needsClean: return AppColors.tableNeedsClean;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = table.currentOrderId == null
        ? null
        : store.orders.cast<dynamic>().firstWhere((o) => o.id == table.currentOrderId, orElse: () => null);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.08),
          border: Border.all(color: _color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.chair, color: _color),
            const Spacer(),
            Text(table.tableName, style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: _color)),
          ]),
          const Spacer(),
          Text(table.status.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
          const SizedBox(height: 2),
          Text(table.capacity.toString() + ' chỗ',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (order != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(order.orderCode,
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  void _showActions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
            title: Text('Tạo đơn cho ' + table.tableName),
            onTap: () {
              Navigator.pop(ctx);
              ctx.go('/cashier');
            },
          ),
          ...TableStatus.values.where((s) => s != table.status).map((s) => ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text('Chuyển sang: ' + s.label),
                onTap: () {
                  store.setTableStatus(table.id, s);
                  Navigator.pop(ctx);
                },
              )),
        ]),
      ),
    );
  }
}
