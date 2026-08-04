import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';
import 'revenue_chart.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final auth = context.watch<AuthProvider>();
    final revToday = store.revenueToday;
    final revYesterday = store.revenueYesterday;
    final ordersToday = store.ordersTodayCount;
    final lowStock = store.ingredients.where((i) => i.isLow).toList();
    final servingTables =
        store.tables.where((t) => t.status == TableStatus.serving).length;
    final totalCustomers = store.customers.length;
    final topProducts = store.topProducts(days: 7, limit: 5);
    final slowProducts = store.slowProducts(days: 7).take(3).toList();
    final restock = store.suggestRestock();
    final last7 = store.revenueLast7Days();
    final recentOrders = store.orders.reversed.take(5).toList();
    final cancelled7d = store.orders
        .where((o) =>
            o.orderStatus == OrderStatus.cancelled &&
            o.createdAt
                .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .length;

    final delta = revYesterday > 0
        ? ((revToday - revYesterday) / revYesterday * 100).toStringAsFixed(1)
        : '0';
    final isDown = revYesterday > 0 && revToday < revYesterday * 0.8;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
            'Xin chào, ' + (auth.currentUser?.fullName.split(' ').last ?? '')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context, store),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Tổng quan hôm nay',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(
                  title: 'Doanh thu hôm nay',
                  value: Fmt.money(revToday),
                  subtitle: 'Hôm qua: ' + Fmt.money(revYesterday),
                  icon: Icons.attach_money,
                  color: AppColors.success,
                ),
                StatCard(
                  title: 'Đơn hôm nay',
                  value: ordersToday.toString(),
                  subtitle: 'Tổng: ' + store.orders.length.toString(),
                  icon: Icons.receipt_long,
                  color: AppColors.info,
                ),
                StatCard(
                  title: 'Khách hàng',
                  value: totalCustomers.toString(),
                  icon: Icons.people_alt,
                  color: AppColors.secondary,
                ),
                StatCard(
                  title: 'Bàn đang phục vụ',
                  value: servingTables.toString() +
                      ' / ' +
                      store.tables.length.toString(),
                  icon: Icons.table_restaurant,
                  color: AppColors.primary,
                ),
              ],
            ),
            if (isDown ||
                lowStock.isNotEmpty ||
                restock.isNotEmpty ||
                cancelled7d >= 5) ...[
              const SizedBox(height: 20),
              const Text('🔔 Cảnh báo thông minh',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (isDown)
                _alertCard(
                  icon: Icons.trending_down,
                  color: AppColors.danger,
                  title: 'Doanh thu giảm ' + delta + '% so với hôm qua',
                  subtitle: 'Cần xem lại nguyên nhân và đẩy mạnh khuyến mãi',
                ),
              if (lowStock.isNotEmpty)
                _alertCard(
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.warning,
                  title: lowStock.length.toString() + ' nguyên liệu sắp hết',
                  subtitle: lowStock.take(3).map((e) => e.name).join(', '),
                  onTap: () => context.go('/inventory'),
                ),
              if (restock.isNotEmpty)
                _alertCard(
                  icon: Icons.shopping_cart_outlined,
                  color: AppColors.info,
                  title: 'Gợi ý nhập hàng',
                  subtitle: restock.take(3).map((e) => e.key.name).join(', '),
                  onTap: () => context.go('/inventory'),
                ),
              if (slowProducts.isNotEmpty)
                _alertCard(
                  icon: Icons.lightbulb_outline,
                  color: AppColors.accent,
                  title: 'Gợi ý khuyến mãi',
                  subtitle: 'Các món bán chậm: ' +
                      slowProducts.take(3).map((e) => e.key.name).join(', '),
                  onTap: () => context.go('/vouchers'),
                ),
              if (cancelled7d >= 5)
                _alertCard(
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                  title: cancelled7d.toString() + ' đơn bị hủy trong 7 ngày',
                  subtitle: 'Kiểm tra nguyên nhân hủy đơn',
                  onTap: () => context.go('/orders'),
                ),
            ],
            const SizedBox(height: 20),
            _sectionTitle('📈 Doanh thu 7 ngày'),
            const SizedBox(height: 8),
            RevenueChart(data: last7),
            const SizedBox(height: 20),
            _sectionTitle('🔥 Top 5 món bán chạy',
                onMore: () => context.go('/reports')),
            const SizedBox(height: 8),
            if (topProducts.isEmpty)
              const EmptyState(emoji: '📊', title: 'Chưa có dữ liệu')
            else
              ...topProducts.asMap().entries.map((e) => _topRow(e.key + 1,
                  e.value.key.name, e.value.key.emoji, e.value.value)),
            const SizedBox(height: 20),
            _sectionTitle('🧾 Đơn hàng gần đây',
                onMore: () => context.go('/orders')),
            const SizedBox(height: 8),
            ...recentOrders.map((o) => Card(
                  child: ListTile(
                    onTap: () => context.go('/orders/' + o.id),
                    leading:
                        const Icon(Icons.receipt, color: AppColors.primary),
                    title:
                        Text(o.orderCode + ' • ' + (o.tableName ?? 'Mang đi')),
                    subtitle: Text(
                        Fmt.relative(o.createdAt) + ' • ' + Fmt.money(o.total)),
                    trailing: StatusBadge.order(o.orderStatus),
                  ),
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, {VoidCallback? onMore}) => Row(
        children: [
          Text(t,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          if (onMore != null)
            TextButton(onPressed: onMore, child: const Text('Xem tất cả')),
        ],
      );

  Widget _alertCard({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, color: color)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _topRow(int rank, String name, String emoji, int count) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: rank <= 3 ? AppColors.accent : AppColors.border,
            child: Text(rank.toString(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(emoji + ' ' + name),
          trailing: Text(count.toString() + ' ly',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  void _showNotifications(BuildContext context, DataStore store) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final list = store.notificationsForRole(UserRole.admin);
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
