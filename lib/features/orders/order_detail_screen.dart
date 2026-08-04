import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/services/data_store.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final orders = store.orders;
    final order = orders.cast<dynamic>().firstWhere((o) => o.id == orderId, orElse: () => null);
    if (order == null) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy đơn')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order.orderCode),
        actions: [
          if (order.orderStatus != OrderStatus.cancelled && order.paymentStatus != PaymentStatus.paid)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
              onPressed: () {
                store.cancelOrder(order.id);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  StatusBadge.order(order.orderStatus),
                  const SizedBox(width: 8),
                  if (order.paymentStatus == PaymentStatus.paid)
                    StatusBadge(label: 'Đã TT', color: AppColors.success, icon: Icons.check),
                ]),
                const SizedBox(height: 8),
                _row('Bàn', order.tableName ?? 'Mang đi'),
                _row('Khách hàng', order.customerName ?? '—'),
                _row('Thu ngân', order.cashierName),
                _row('Loại đơn', order.orderType.label),
                _row('Tạo lúc', Fmt.dateTime(order.createdAt)),
                if (order.completedAt != null)
                  _row('Hoàn thành', Fmt.dateTime(order.completedAt!)),
                if (order.paymentMethod != null)
                  _row('Thanh toán', order.paymentMethod!.label),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chi tiết món', style: TextStyle(fontWeight: FontWeight.w700))),
          ...order.items.map<Widget>((it) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                  child: Text(it.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.quantity.toString() + 'x ' + it.productName + ' (' + it.size.code + ')',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Đường ' + it.sugar.label + ' • ' + it.ice.label,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (it.toppingNames.isNotEmpty)
                    Text('+ ' + it.toppingNames.join(', '),
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ])),
                Text(Fmt.money(it.totalPrice), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ),
          )).toList(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _summary('Tạm tính', order.subtotal),
                if (order.discount > 0)
                  _summary('Giảm giá' + (order.voucherCode != null ? ' (' + order.voucherCode! + ')' : ''), -order.discount, color: AppColors.success),
                const Divider(),
                _summary('Tổng cộng', order.total, bold: true),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _summary(String label, double value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 16 : 14)),
          const Spacer(),
          Text(Fmt.money(value), style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color ?? (bold ? AppColors.primary : AppColors.textPrimary), fontSize: bold ? 16 : 14)),
        ]),
      );
}
