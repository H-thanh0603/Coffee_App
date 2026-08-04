import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/services/data_store.dart';
import '../cart/cart_provider.dart';
import 'checkout_dialog.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final store = context.watch<DataStore>();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Giỏ hàng',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: cart.items.isEmpty
                  ? const EmptyState(emoji: '🛒', title: 'Chưa có món nào')
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _OrderTypePicker(),
                        const SizedBox(height: 12),
                        if (cart.orderType == OrderType.dineIn)
                          _TablePicker(store: store),
                        _CustomerPicker(store: store),
                        if (cart.customerId != null) _PointsTile(store: store),
                        const SizedBox(height: 12),
                        const Text('Món đã chọn',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...cart.items.map((item) => _CartItemTile(item: item)),
                        const SizedBox(height: 12),
                        _VoucherPicker(store: store),
                        const SizedBox(height: 12),
                      ],
                    ),
            ),
            if (cart.items.isNotEmpty) _SummaryBar(),
          ],
        ),
      ),
    );
  }
}

class _OrderTypePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return SegmentedButton<OrderType>(
      segments: OrderType.values
          .map((t) => ButtonSegment(
              value: t,
              label: Text(t.label),
              icon: Icon(t == OrderType.dineIn
                  ? Icons.restaurant
                  : Icons.shopping_bag_outlined)))
          .toList(),
      selected: {cart.orderType},
      onSelectionChanged: (s) => cart.setOrderType(s.first),
    );
  }
}

class _TablePicker extends StatelessWidget {
  final DataStore store;
  const _TablePicker({required this.store});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _pickTable(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.table_restaurant, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(cart.tableName ?? 'Chọn bàn',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_right),
          ]),
        ),
      ),
    );
  }

  void _pickTable(BuildContext context) {
    final cart = context.read<CartProvider>();
    showModalBottomSheet(
        context: context,
        builder: (_) {
          final tables = store.tables;
          return SizedBox(
            height: 480,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1),
              itemCount: tables.length,
              itemBuilder: (_, i) {
                final t = tables[i];
                final selected = cart.tableId == t.id;
                return InkWell(
                  onTap: () {
                    cart.setTable(t.id, t.tableName);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chair,
                            color: selected ? Colors.white : AppColors.primary),
                        const SizedBox(height: 4),
                        Text(t.tableName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary)),
                        Text(t.capacity.toString() + ' chỗ',
                            style: TextStyle(
                                fontSize: 11,
                                color: selected
                                    ? Colors.white70
                                    : AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        });
  }
}

class _CustomerPicker extends StatelessWidget {
  final DataStore store;
  const _CustomerPicker({required this.store});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return InkWell(
      onTap: () => _pickCustomer(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(cart.customerName ?? 'Chọn khách hàng (không bắt buộc)',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (cart.customerId != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => cart.setCustomer(null, null),
            )
          else
            const Icon(Icons.keyboard_arrow_right),
        ]),
      ),
    );
  }

  void _pickCustomer(BuildContext context) {
    final cart = context.read<CartProvider>();
    final ctrl = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: 500,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo tên hoặc SĐT',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => (ctx as Element).markNeedsBuild(),
                  ),
                ),
                Expanded(
                  child: ListView(
                      children: store.customers
                          .where((c) {
                            final q = ctrl.text.toLowerCase();
                            return q.isEmpty ||
                                c.fullName.toLowerCase().contains(q) ||
                                c.phone.contains(q);
                          })
                          .map((c) => ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.person)),
                                title: Text(c.fullName),
                                subtitle: Text(c.phone +
                                    ' • ' +
                                    c.points.toString() +
                                    ' điểm • ' +
                                    c.rank.label),
                                onTap: () {
                                  cart.setCustomer(c.id, c.fullName);
                                  Navigator.pop(ctx);
                                },
                              ))
                          .toList()),
                ),
              ]),
            ),
          );
        });
  }
}

class _PointsTile extends StatelessWidget {
  final DataStore store;
  const _PointsTile({required this.store});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final c =
        cart.customerId == null ? null : store.findCustomer(cart.customerId!);
    if (c == null) return const SizedBox.shrink();
    final canRedeem = c.points >= 100;
    final using = cart.pointsUsed > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: const Text('Dùng điểm giảm giá',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          canRedeem
              ? (c.points.toString() +
                  ' điểm • 100 điểm = 10.000đ' +
                  (using ? '\nGiảm ' + Fmt.money(cart.pointsDiscount) : ''))
              : 'Chưa đủ 100 điểm để đổi',
          style: const TextStyle(fontSize: 12),
        ),
        value: using,
        onChanged: canRedeem
            ? (v) => cart.setUsePoints(maxRedeemable: c.points, value: v)
            : null,
        activeColor: AppColors.primary,
      ),
    );
  }
}

class _VoucherPicker extends StatelessWidget {
  final DataStore store;
  const _VoucherPicker({required this.store});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return InkWell(
      onTap: () => _pickVoucher(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          color: AppColors.accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.discount, color: AppColors.accent),
          const SizedBox(width: 10),
          Text(cart.voucher?.code ?? 'Áp dụng voucher',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (cart.voucher != null) ...[
            Text('-' + Fmt.money(cart.discount),
                style: const TextStyle(color: AppColors.success)),
            const SizedBox(width: 6),
            IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => cart.setVoucher(null)),
          ] else
            const Icon(Icons.keyboard_arrow_right),
        ]),
      ),
    );
  }

  void _pickVoucher(BuildContext context) {
    final cart = context.read<CartProvider>();
    showModalBottomSheet(
        context: context,
        builder: (ctx) {
          final available = store.vouchers
              .where((v) => v.isAvailable && cart.subtotal >= v.minOrderValue)
              .toList();
          if (available.isEmpty) {
            return const SizedBox(
                height: 200,
                child: EmptyState(
                    emoji: '🎁', title: 'Không có voucher khả dụng'));
          }
          return SizedBox(
            height: 500,
            child: ListView(
                children: available
                    .map((v) => Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.discount,
                                color: AppColors.accent),
                            title: Text(v.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(v.name +
                                '\nGiảm ' +
                                Fmt.money(v.calcDiscount(cart.subtotal))),
                            isThreeLine: true,
                            onTap: () {
                              cart.setVoucher(v);
                              Navigator.pop(ctx);
                            },
                          ),
                        ))
                    .toList()),
          );
        });
  }
}

class _CartItemTile extends StatelessWidget {
  final dynamic item;
  const _CartItemTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                'Size ' +
                    item.size.code +
                    ' • Đường ' +
                    item.sugar.label +
                    ' • ' +
                    item.ice.label,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              if ((item.toppingNames as List).isNotEmpty)
                Text('+ ' + (item.toppingNames as List).join(', '),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(Fmt.money(item.totalPrice),
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          Column(children: [
            IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                onPressed: () => cart.incQty(item.id),
                color: AppColors.primary),
            Text(item.quantity.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                onPressed: () => cart.decQty(item.id),
                color: AppColors.danger),
          ]),
        ]),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _row('Tạm tính', Fmt.money(cart.subtotal)),
          if (cart.discount > 0)
            _row('Giảm giá', '-' + Fmt.money(cart.discount),
                color: AppColors.success),
          if (cart.pointsDiscount > 0)
            _row('Điểm dùng (' + cart.pointsUsed.toString() + ')',
                '-' + Fmt.money(cart.pointsDiscount),
                color: AppColors.success),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Divider(height: 1)),
          _row('Tổng cộng', Fmt.money(cart.total), bold: true),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              if (cart.orderType == OrderType.dineIn && cart.tableId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng chọn bàn')),
                );
                return;
              }
              showDialog(
                  context: context, builder: (_) => const CheckoutDialog());
            },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Thanh toán'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: color ?? AppColors.textSecondary,
                    fontSize: bold ? 16 : 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: color ?? AppColors.textPrimary,
                    fontSize: bold ? 18 : 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      );
}
