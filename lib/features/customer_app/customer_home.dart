import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/product.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import '../pos/cart_panel.dart';
import '../pos/product_options_sheet.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title:
            Text('Chào ' + (auth.currentUser?.fullName.split(' ').last ?? '')),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.local_cafe), text: 'Menu'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Đơn của tôi'),
            Tab(icon: Icon(Icons.card_giftcard), text: 'Voucher'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MenuTab(),
          _MyOrdersTab(),
          _VoucherTab(),
        ],
      ),
    );
  }
}

class _MenuTab extends StatefulWidget {
  const _MenuTab();
  @override
  State<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends State<_MenuTab> {
  String? _catId;
  String _q = '';

  /// Món hay dùng của tài khoản khách (từ lịch sử đơn đã đặt), top 3.
  List<MapEntry<Product, int>> _myFavorites(DataStore store, String? userId) {
    final counts = <String, int>{};
    for (final o in store.orders.where((o) => o.cashierId == userId)) {
      for (final it in o.items) {
        counts[it.productId] = (counts[it.productId] ?? 0) + it.quantity;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final res = <MapEntry<Product, int>>[];
    for (final e in sorted.take(3)) {
      final p = store.products.cast<Product?>().firstWhere(
            (x) => x?.id == e.key,
            orElse: () => null,
          );
      if (p != null) res.add(MapEntry(p, e.value));
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final cart = context.watch<CartProvider>();
    final auth = context.read<AuthProvider>();
    final favs = _myFavorites(store, auth.currentUser?.id);
    final products = store.products.where((p) {
      if (p.hidden) return false;
      if (_catId != null && p.categoryId != _catId) return false;
      if (_q.isNotEmpty && !p.name.toLowerCase().contains(_q.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          decoration: const InputDecoration(
              hintText: 'Tìm món',
              prefixIcon: Icon(Icons.search),
              isDense: true),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _catId == null,
                    onSelected: (_) => setState(() => _catId = null),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _catId == null
                            ? Colors.white
                            : AppColors.textPrimary))),
            ...store.categories.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: Text(c.icon),
                    label: Text(c.name),
                    selected: _catId == c.id,
                    onSelected: (_) => setState(() => _catId = c.id),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _catId == c.id
                            ? Colors.white
                            : AppColors.textPrimary),
                  ),
                )),
          ],
        ),
      ),
      if (favs.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: const [
            Text('⭐ Món bạn hay dùng',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: favs
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: Text(e.key.emoji,
                            style: const TextStyle(fontSize: 16)),
                        label:
                            Text(e.key.name + ' (' + e.value.toString() + ')'),
                        onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                ProductOptionsSheet(product: e.key)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
      ],
      Expanded(
        child: products.isEmpty
            ? const EmptyState(emoji: '🍴', title: 'Không có món')
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return InkWell(
                    onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ProductOptionsSheet(product: p)),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                  child: Text(p.emoji,
                                      style: const TextStyle(fontSize: 44))),
                            )),
                            const SizedBox(height: 10),
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(Fmt.money(p.basePrice),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  );
                },
              ),
      ),
      if (cart.itemCount > 0)
        Material(
          color: AppColors.primary,
          child: InkWell(
            onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const CartPanel()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                const SizedBox(width: 8),
                Text(cart.itemCount.toString() + ' món',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(Fmt.money(cart.total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _MyOrdersTab extends StatelessWidget {
  const _MyOrdersTab();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final store = context.watch<DataStore>();
    final myOrders = store.orders
        .where((o) =>
            o.customerId == auth.currentUser?.id ||
            o.cashierId == auth.currentUser?.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (myOrders.isEmpty) {
      return const EmptyState(emoji: '🧾', title: 'Bạn chưa có đơn hàng nào');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: myOrders.length,
      itemBuilder: (_, i) {
        final o = myOrders[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: AppColors.primary),
            title: Text(o.orderCode + ' • ' + Fmt.money(o.total),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(o.itemCount.toString() +
                ' món • ' +
                Fmt.relative(o.createdAt) +
                '\n' +
                o.orderStatus.label),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

class _VoucherTab extends StatelessWidget {
  const _VoucherTab();
  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final list = store.vouchers.where((v) => v.isAvailable).toList();
    if (list.isEmpty) {
      return const EmptyState(emoji: '🎁', title: 'Hiện chưa có voucher nào');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final v = list[i];
        return Card(
          color: AppColors.accent.withOpacity(0.08),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accent,
              child: Icon(Icons.discount, color: Colors.white),
            ),
            title: Text(v.code,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(v.name + '\nHSD: ' + Fmt.date(v.endDate)),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
