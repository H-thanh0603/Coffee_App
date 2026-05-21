import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/services/data_store.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});
  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    var orders = List.of(store.orders);
    if (_filter == 'today') {
      final now = DateTime.now();
      orders = orders.where((o) => o.createdAt.year == now.year &&
          o.createdAt.month == now.month && o.createdAt.day == now.day).toList();
    } else if (_filter == 'unpaid') {
      orders = orders.where((o) => o.paymentStatus != PaymentStatus.paid).toList();
    } else if (_filter == 'cancelled') {
      orders = orders.where((o) => o.orderStatus == OrderStatus.cancelled).toList();
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Lịch sử đơn hàng')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            for (final f in const [['all','Tất cả'],['today','Hôm nay'],['unpaid','Chưa TT'],['cancelled','Đã hủy']])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f[1]),
                  selected: _filter == f[0],
                  onSelected: (_) => setState(() => _filter = f[0]),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _filter == f[0] ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: orders.isEmpty
              ? const EmptyState(emoji: '🧾', title: 'Chưa có đơn hàng')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.go('/orders/' + o.id),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Row(children: [
                          Text(o.orderCode, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          StatusBadge.order(o.orderStatus),
                        ]),
                        subtitle: Text(
                            (o.tableName ?? 'Mang đi') + ' • ' +
                            o.itemCount.toString() + ' món • ' +
                            Fmt.dateTime(o.createdAt)),
                        trailing: Text(Fmt.money(o.total),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
