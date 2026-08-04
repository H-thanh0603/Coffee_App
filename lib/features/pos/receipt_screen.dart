import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order.dart';

/// Màn hóa đơn sau khi thanh toán (cũng mở từ chi tiết đơn).
class ReceiptScreen extends StatelessWidget {
  final AppOrder order;
  const ReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hóa đơn'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 48),
              const SizedBox(height: 8),
              const Text('Thanh toán thành công',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 4),
              Text(order.orderCode,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _row('Thời gian', Fmt.dateTime(order.createdAt)),
                _row('Bàn', order.tableName ?? 'Mang đi'),
                _row('Khách hàng', order.customerName ?? '—'),
                _row('Loại đơn', order.orderType.label),
                _row('Thu ngân', order.cashierName),
                _row('Thanh toán', order.paymentMethod?.label ?? '—'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Chi tiết món',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ...order.items.map<Widget>((it) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10)),
                      child:
                          Text(it.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                it.quantity.toString() +
                                    'x ' +
                                    it.productName +
                                    ' (' +
                                    it.size.code +
                                    ')',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                'Đường ' +
                                    it.sugar.label +
                                    ' • ' +
                                    it.ice.label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            if (it.toppingNames.isNotEmpty)
                              Text('+ ' + it.toppingNames.join(', '),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                          ]),
                    ),
                    Text(Fmt.money(it.totalPrice),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ]),
                ),
              )),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _sum('Tạm tính', order.subtotal),
                if (order.discount > 0)
                  _sum(
                      'Giảm giá' +
                          (order.voucherCode != null
                              ? ' (' + order.voucherCode! + ')'
                              : ''),
                      -order.discount,
                      color: AppColors.success),
                if (order.pointsDiscount > 0)
                  _sum('Điểm dùng (' + order.pointsUsed.toString() + ' điểm)',
                      -order.pointsDiscount,
                      color: AppColors.success),
                const Divider(),
                _sum('Tổng thanh toán', order.total, bold: true),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _sum(String label, double value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  fontSize: bold ? 16 : 14)),
          const Spacer(),
          Text(Fmt.money(value),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: color ??
                      (bold ? AppColors.primary : AppColors.textPrimary),
                  fontSize: bold ? 16 : 14)),
        ]),
      );
}
