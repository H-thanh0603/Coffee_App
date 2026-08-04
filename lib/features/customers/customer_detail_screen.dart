import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/services/data_store.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  /// Món hay dùng của khách từ lịch sử đơn (đếm số lần mua, top 5).
  List<MapEntry<Product, int>> _favorites(DataStore store) {
    final counts = <String, int>{};
    for (final o in store.orders.where((o) => o.customerId == customerId)) {
      for (final it in o.items) {
        counts[it.productId] = (counts[it.productId] ?? 0) + it.quantity;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <MapEntry<Product, int>>[];
    for (final e in entries.take(5)) {
      final p = store.products.cast<Product?>().firstWhere(
            (x) => x?.id == e.key,
            orElse: () => null,
          );
      if (p != null) result.add(MapEntry(p, e.value));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final c = store.findCustomer(customerId);
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy khách')));
    }
    final favorites = _favorites(store);
    final history = store.orders
        .where((o) => o.customerId == customerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Khách hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, store, c),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Color(c.rank.colorValue),
                child: Text(c.fullName.characters.first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Text(c.fullName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(c.rank.colorValue).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(c.rank.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(c.rank.colorValue),
                        fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 24),
              _info(Icons.phone, 'SĐT', c.phone),
              if (c.email.isNotEmpty) _info(Icons.email, 'Email', c.email),
              _info(
                  Icons.stars, 'Điểm tích lũy', c.points.toString() + ' điểm'),
              _info(Icons.attach_money, 'Đã chi', Fmt.money(c.totalSpent)),
              _info(Icons.receipt_long, 'Số đơn', c.totalOrders.toString()),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('☕ Món hay dùng',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (favorites.isEmpty)
          Text('Chưa có dữ liệu mua hàng',
              style: TextStyle(color: AppColors.textSecondary))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: favorites
                .map((e) => Chip(
                      avatar: Text(e.key.emoji,
                          style: const TextStyle(fontSize: 16)),
                      label: Text(
                          e.key.name + ' (' + e.value.toString() + ' lần)'),
                    ))
                .toList(),
          ),
        const SizedBox(height: 16),
        const Text('🧾 Lịch sử đơn hàng',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const EmptyState(emoji: '🧾', title: 'Khách chưa có đơn hàng')
        else
          ...history.take(10).map((o) => Card(
                child: ListTile(
                  onTap: () => context.go('/orders/' + o.id),
                  leading: const Icon(Icons.receipt, color: AppColors.primary),
                  title: Text(o.orderCode + ' • ' + Fmt.money(o.total),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(Fmt.dateTime(o.createdAt) +
                      ' • ' +
                      o.itemCount.toString() +
                      ' món'),
                  trailing: StatusBadge.order(o.orderStatus),
                ),
              )),
      ]),
    );
  }

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  void _edit(BuildContext ctx, DataStore store, Customer c) {
    final name = TextEditingController(text: c.fullName);
    final phone = TextEditingController(text: c.phone);
    final email = TextEditingController(text: c.email);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Sửa khách hàng'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Họ tên')),
          TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'SĐT')),
          TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
              store.updateCustomer(Customer(
                id: c.id,
                fullName: name.text.trim(),
                phone: phone.text.trim(),
                email: email.text.trim(),
                points: c.points,
                totalSpent: c.totalSpent,
                totalOrders: c.totalOrders,
                favoriteProducts: c.favoriteProducts,
                createdAt: c.createdAt,
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
