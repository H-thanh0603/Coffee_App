import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/cafe_table.dart';
import '../../data/models/order.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final tables = store.tables;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Sơ đồ bàn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context, store),
          ),
        ],
      ),
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

  void _showNotifications(BuildContext context, DataStore store) {
    final role = context.read<AuthProvider>().role;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final list =
            role == null ? <dynamic>[] : store.notificationsForRole(role);
        if (list.isEmpty) {
          return const SizedBox(
              height: 200,
              child: EmptyState(emoji: '🔔', title: 'Không có thông báo'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final n = list[i];
            return ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(n.title),
              subtitle: Text(n.message),
              trailing: Text(Fmt.relative(n.createdAt),
                  style: const TextStyle(fontSize: 11)),
            );
          },
        );
      },
    );
  }
}

class _TableCard extends StatelessWidget {
  final CafeTable table;
  final DataStore store;
  const _TableCard({required this.table, required this.store});

  Color get _color {
    switch (table.status) {
      case TableStatus.empty:
        return AppColors.tableEmpty;
      case TableStatus.serving:
        return AppColors.tableServing;
      case TableStatus.waiting:
        return AppColors.tableWaiting;
      case TableStatus.reserved:
        return AppColors.tableReserved;
      case TableStatus.needsClean:
        return AppColors.tableNeedsClean;
    }
  }

  AppOrder? get _order => table.currentOrderId == null
      ? null
      : store.orders
          .cast<AppOrder?>()
          .firstWhere((o) => o?.id == table.currentOrderId, orElse: () => null);

  @override
  Widget build(BuildContext context) {
    final order = _order;
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
            Text(table.tableName,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18, color: _color)),
          ]),
          const Spacer(),
          Text(table.status.label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
          const SizedBox(height: 2),
          Text(table.capacity.toString() + ' chỗ',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (order != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(order.orderCode,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }

  void _showActions(BuildContext ctx) {
    final order = _order;
    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
            title: Text('Tạo đơn cho ' + table.tableName),
            subtitle: table.status != TableStatus.empty
                ? const Text('Sẽ chọn sẵn bàn trong giỏ',
                    style: TextStyle(fontSize: 11))
                : null,
            onTap: () {
              final cart = ctx.read<CartProvider>();
              cart.setTable(table.id, table.tableName);
              Navigator.pop(ctx);
              ctx.go('/cashier');
            },
          ),
          if (order != null) ...[
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
              title: const Text('Chuyển bàn'),
              onTap: () {
                Navigator.pop(ctx);
                _pickTableToMove(ctx, order);
              },
            ),
            ListTile(
              leading: const Icon(Icons.merge, color: AppColors.accent),
              title: const Text('Gộp bàn vào...'),
              onTap: () {
                Navigator.pop(ctx);
                _pickTableToMerge(ctx);
              },
            ),
          ],
          ...TableStatus.values
              .where((s) => s != table.status)
              .map((s) => ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: Text('Chuyển trạng thái: ' + s.label),
                    onTap: () {
                      store.setTableStatus(table.id, s);
                      Navigator.pop(ctx);
                    },
                  )),
        ]),
      ),
    );
  }

  /// Chọn bàn trống để chuyển order sang.
  void _pickTableToMove(BuildContext ctx, AppOrder order) {
    final available = store.tables
        .where((t) => t.id != table.id && t.status == TableStatus.empty)
        .toList();
    showModalBottomSheet(
      context: ctx,
      builder: (_) => available.isEmpty
          ? const SizedBox(
              height: 160, child: Center(child: Text('Không có bàn trống')))
          : SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: available
                    .map((t) => ListTile(
                          leading:
                              const Icon(Icons.chair, color: AppColors.primary),
                          title: Text('Chuyển sang ' + t.tableName),
                          subtitle: Text(t.capacity.toString() +
                              ' chỗ • ' +
                              t.status.label),
                          onTap: () {
                            store.moveOrderToTable(order.id, t.id);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            ),
    );
  }

  /// Chọn bàn đang phục vụ để gộp (bàn này sẽ gộp vào bàn kia).
  void _pickTableToMerge(BuildContext ctx) {
    final serving = store.tables
        .where((t) => t.id != table.id && t.status == TableStatus.serving)
        .toList();
    showModalBottomSheet(
      context: ctx,
      builder: (_) => serving.isEmpty
          ? const SizedBox(
              height: 160,
              child: Center(child: Text('Không có bàn đang phục vụ khác')))
          : SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: serving
                    .map((t) => ListTile(
                          leading: Icon(Icons.merge, color: AppColors.accent),
                          title: Text(
                              'Gộp ' + table.tableName + ' vào ' + t.tableName),
                          subtitle:
                              Text('Toàn bộ món sẽ dồn về ' + t.tableName),
                          onTap: () {
                            store.mergeTables(table.id, t.id);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            ),
    );
  }
}
