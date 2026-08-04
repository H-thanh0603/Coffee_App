import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/order.dart';
import '../../data/services/data_store.dart';

class BaristaScreen extends StatefulWidget {
  const BaristaScreen({super.key});
  @override
  State<BaristaScreen> createState() => _BaristaScreenState();
}

class _BaristaScreenState extends State<BaristaScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
final pending = store.orders.where((o) =>
        (o.orderStatus == OrderStatus.pending || o.orderStatus == OrderStatus.confirmed) &&
        o.orderStatus != OrderStatus.cancelled).toList();
    final preparing = store.orders.where((o) => o.orderStatus == OrderStatus.preparing).toList();
    final ready = store.orders.where((o) =>
        o.orderStatus == OrderStatus.ready || o.orderStatus == OrderStatus.served).toList();

    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    preparing.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    ready.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Quầy pha chế'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Chờ pha (' + pending.length.toString() + ')'),
            Tab(text: 'Đang pha (' + preparing.length.toString() + ')'),
            Tab(text: 'Hoàn thành (' + ready.length.toString() + ')'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _list(pending, 'pending', store),
          _list(preparing, 'preparing', store),
          _list(ready, 'ready', store),
        ],
      ),
    );
  }

  Widget _list(List<AppOrder> orders, String stage, DataStore store) {
    if (orders.isEmpty) {
      return const EmptyState(emoji: '☕', title: 'Không có đơn nào');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(order: orders[i], stage: stage, store: store),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final AppOrder order;
  final String stage;
  final DataStore store;
  const _OrderCard({required this.order, required this.stage, required this.store});

  @override
  Widget build(BuildContext context) {
    final age = order.age;
    final isLate = stage != 'ready' && age.inMinutes > 10;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isLate ? AppColors.danger : AppColors.border, width: isLate ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(order.orderCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 8),
            StatusBadge.order(order.orderStatus),
            const Spacer(),
            Icon(Icons.schedule, size: 14, color: isLate ? AppColors.danger : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(Fmt.relative(order.createdAt),
                style: TextStyle(fontSize: 12, color: isLate ? AppColors.danger : AppColors.textSecondary, fontWeight: isLate ? FontWeight.w700 : FontWeight.normal)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.table_restaurant, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(order.tableName ?? 'Mang đi',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          const Divider(height: 16),
          ...order.items.map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                child: Text(it.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.quantity.toString() + 'x ' + it.productName + ' (' + it.size.code + ')',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Đường ' + it.sugar.label + ' • ' + it.ice.label,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (it.toppingNames.isNotEmpty)
                    Text('+ ' + it.toppingNames.join(', '),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (it.note.isNotEmpty)
                    Text('💬 ' + it.note,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.warning)),
                ]),
              ),
            ]),
          )),
          if (order.note.isNotEmpty) ...[
            const Divider(height: 16),
            Text('Ghi chú đơn: ' + order.note,
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.warning)),
          ],
          const SizedBox(height: 12),
          _actions(context),
        ]),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    if (stage == 'pending') {
      return Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => store.updateOrderStatus(order.id, OrderStatus.preparing),
            icon: const Icon(Icons.coffee),
            label: const Text('Bắt đầu pha'),
          ),
        ),
      ]);
    }
    if (stage == 'preparing') {
      return Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => store.updateOrderStatus(order.id, OrderStatus.ready),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Hoàn thành'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          ),
        ),
      ]);
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: order.orderStatus == OrderStatus.served
              ? null
              : () => store.updateOrderStatus(order.id, OrderStatus.served),
          icon: const Icon(Icons.delivery_dining),
          label: Text(order.orderStatus == OrderStatus.served ? 'Đã giao' : 'Đánh dấu đã giao'),
        ),
      ),
    ]);
  }
}
