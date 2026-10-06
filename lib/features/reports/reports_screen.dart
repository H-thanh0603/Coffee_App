import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/stat_card.dart';
import '../../data/services/data_store.dart';
import '../dashboard/revenue_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _range = '7d';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final days = _range == '7d' ? 7 : (_range == '30d' ? 30 : 1);
    final since = DateTime.now().subtract(Duration(days: days));
    final orders =
        store.paidOrders.where((o) => o.createdAt.isAfter(since)).toList();
    final revenue = orders.fold<double>(0, (s, o) => s + o.total);
    final avgOrder = orders.isEmpty ? 0 : revenue / orders.length;
    final profit = store.profitInRange(days);
    final chartData = days == 1
        ? [MapEntry('Hôm nay', revenue)]
        : store.revenueLastNDays(days);
    final top = store.topProducts(days: days, limit: 10);
    final slow = store.slowProducts(days: days);

    final byMethod = <PaymentMethod, double>{};
    for (final o in orders) {
      if (o.paymentMethod != null) {
        byMethod[o.paymentMethod!] =
            (byMethod[o.paymentMethod!] ?? 0) + o.total;
      }
    }
    final byStaff = <String, double>{};
    for (final o in orders) {
      byStaff[o.cashierName] = (byStaff[o.cashierName] ?? 0) + o.total;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Báo cáo doanh thu')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [
          _rangeChip('today', 'Hôm nay'),
          _rangeChip('7d', '7 ngày'),
          _rangeChip('30d', '30 ngày'),
        ]),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            StatCard(
                title: 'Doanh thu',
                value: Fmt.money(revenue),
                icon: Icons.attach_money,
                color: AppColors.success),
            StatCard(
                title: 'Số đơn',
                value: orders.length.toString(),
                icon: Icons.receipt_long,
                color: AppColors.info),
            StatCard(
                title: 'TB/đơn',
                value: Fmt.money(avgOrder.toDouble()),
                icon: Icons.bar_chart,
                color: AppColors.primary),
            StatCard(
                title: 'Khách',
                value: store.customers.length.toString(),
                icon: Icons.people,
                color: AppColors.secondary),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Lợi nhuận ước tính',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.trending_up, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.money(profit),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.success)),
                      Text(
                        'Biên lợi nhuận: ' +
                            (revenue > 0
                                ? ((profit / revenue) * 100)
                                        .toStringAsFixed(1) +
                                    '%'
                                : '—'),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Doanh thu theo ngày',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        RevenueChart(data: chartData, labelEvery: days >= 30 ? 5 : 1),
        const SizedBox(height: 16),
        const Text('Giờ cao điểm (7 ngày)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        _peakHourCard(context, store),
        const SizedBox(height: 16),
        _section(
            'Top món bán chạy',
            top
                .map(
                  (e) => ListTile(
                    leading:
                        Text(e.key.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(e.key.name),
                    trailing: Text(e.value.toString() + ' ly',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )
                .toList()),
        if (slow.isNotEmpty)
          _section(
              'Món bán chậm',
              slow
                  .take(5)
                  .map(
                    (e) => ListTile(
                      leading: Text(e.key.emoji,
                          style: const TextStyle(fontSize: 24)),
                      title: Text(e.key.name),
                      trailing: Text(e.value.toString() + ' ly',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning)),
                    ),
                  )
                  .toList()),
        _section(
            'Doanh thu theo phương thức',
            byMethod.entries
                .map(
                  (e) => ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(e.key.label),
                    trailing: Text(Fmt.money(e.value),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                )
                .toList()),
        _section(
            'Doanh thu theo nhân viên',
            byStaff.entries
                .map(
                  (e) => ListTile(
                    leading: const Icon(Icons.badge),
                    title: Text(e.key),
                    trailing: Text(Fmt.money(e.value),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                )
                .toList()),
      ]),
    );
  }

  Widget _rangeChip(String code, String label) => ChoiceChip(
        label: Text(label),
        selected: _range == code,
        onSelected: (_) => setState(() => _range = code),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
            color: _range == code ? Colors.white : AppColors.textPrimary),
      );

  /// Biểu đồ cột đơn theo giờ + gợi ý xếp ca từ dữ liệu đơn thật.
  Widget _peakHourCard(BuildContext context, DataStore store) {
    final counts = store.ordersByHour(days: 7);
    final max = counts.fold<int>(1, (m, e) => e > m ? e : m);
    final peaks = store.peakHours(days: 7);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var h = 6; h <= 22; h++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    height:
                                        70 * (counts[h] / max) + (counts[h] > 0 ? 3 : 0),
                                    decoration: BoxDecoration(
                                      color: peaks.any((e) => e.key == h)
                                          ? AppColors.accent
                                          : AppColors.primary
                                              .withOpacity(0.45),
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(h.toString(),
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.schedule,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(store.shiftSuggestion(days: 7),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text('Không có dữ liệu',
                style: TextStyle(color: AppColors.textSecondary))
          else
            ...children,
        ],
      );
}
