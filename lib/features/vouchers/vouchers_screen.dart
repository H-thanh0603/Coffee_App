import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/voucher.dart';
import '../../data/services/data_store.dart';

class VouchersScreen extends StatelessWidget {
  const VouchersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final list = store.vouchers;
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Voucher / Khuyến mãi'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add), onPressed: () => _addEdit(context, store, null)),
        ],
      ),
      body: list.isEmpty
          ? const EmptyState(emoji: '🎁', title: 'Chưa có voucher')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final v = list[i];
                final available = v.isAvailable;
                return Card(
                  child: ListTile(
                    onTap: () => _addEdit(context, store, v),
                    leading: CircleAvatar(
                      backgroundColor: available ? AppColors.accent : AppColors.border,
                      child: const Icon(Icons.discount, color: Colors.white),
                    ),
                    title: Row(children: [
                      Text(v.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      if (!available)
                        const Text('Hết hạn', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                    ]),
                    subtitle: Text(
                      v.name +
                          '\n' +
                          (v.discountType == DiscountType.percent
                              ? 'Giảm ' + v.discountValue.toStringAsFixed(0) + '%'
                              : 'Giảm ' + Fmt.money(v.discountValue)) +
                          (v.minOrderValue > 0
                              ? ' • Đơn tối thiểu ' + Fmt.money(v.minOrderValue)
                              : '') +
                          '\nĐã dùng ' +
                          v.usedCount.toString() +
                          '/' +
                          v.usageLimit.toString() +
                          ' • HSD: ' +
                          Fmt.date(v.endDate),
                    ),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                        value: v.active,
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          final updated = Voucher(
                            id: v.id,
                            code: v.code,
                            name: v.name,
                            discountType: v.discountType,
                            discountValue: v.discountValue,
                            minOrderValue: v.minOrderValue,
                            maxDiscount: v.maxDiscount,
                            startDate: v.startDate,
                            endDate: v.endDate,
                            usageLimit: v.usageLimit,
                            usedCount: v.usedCount,
                            active: val,
                          );
                          store.updateVoucher(updated);
                        },
                      ),
                      PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                        ],
                        onSelected: (val) {
                          if (val == 'edit') {
                            _addEdit(context, store, v);
                          } else if (val == 'delete') {
                            store.removeVoucher(v.id);
                          }
                        },
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  void _addEdit(BuildContext ctx, DataStore store, Voucher? v) {
    final code = TextEditingController(text: v?.code ?? '');
    final name = TextEditingController(text: v?.name ?? '');
    final value = TextEditingController(
        text: (v?.discountValue ?? 10).toStringAsFixed(0));
    final minOrder = TextEditingController(
        text: (v?.minOrderValue ?? 0).toStringAsFixed(0));
    final maxDiscount = TextEditingController(
        text: (v?.maxDiscount ?? 0).toStringAsFixed(0));
    final usageLimit = TextEditingController(
        text: (v?.usageLimit ?? 100).toStringAsFixed(0));
    DiscountType type = v?.discountType ?? DiscountType.percent;
    DateTime start = v?.startDate ?? DateTime.now();
    DateTime end = v?.endDate ?? DateTime.now().add(const Duration(days: 30));
    var active = v?.active ?? true;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AlertDialog(
          title: Text(v == null ? 'Thêm voucher' : 'Sửa voucher'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: code,
                  decoration: const InputDecoration(labelText: 'Mã voucher')),
              TextField(controller: name,
                  decoration: const InputDecoration(labelText: 'Tên')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: ChoiceChip(
                  label: const Text('Phần trăm'),
                  selected: type == DiscountType.percent,
                  onSelected: (_) => setSt(() => type = DiscountType.percent),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: type == DiscountType.percent
                          ? Colors.white
                          : AppColors.textPrimary),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: ChoiceChip(
                  label: const Text('Số tiền'),
                  selected: type == DiscountType.amount,
                  onSelected: (_) => setSt(() => type = DiscountType.amount),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                      color: type == DiscountType.amount
                          ? Colors.white
                          : AppColors.textPrimary),
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(controller: value,
                        decoration: InputDecoration(
                            labelText: type == DiscountType.percent
                                ? 'Giá trị (%)'
                                : 'Giá trị (đ)'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(controller: minOrder,
                        decoration: const InputDecoration(labelText: 'Đơn tối thiểu'),
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(controller: maxDiscount,
                        decoration: const InputDecoration(labelText: 'Giảm tối đa'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(controller: usageLimit,
                        decoration: const InputDecoration(labelText: 'Lượt dùng'),
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: start,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setSt(() => start = d);
                  },
                  icon: const Icon(Icons.event, size: 16),
                  label: Text('Bắt đầu: ' + Fmt.date(start),
                      style: const TextStyle(fontSize: 12)),
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: end.isAfter(start) ? end : start,
                      firstDate: start,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setSt(() => end = d);
                  },
                  icon: const Icon(Icons.event, size: 16),
                  label: Text('Kết thúc: ' + Fmt.date(end),
                      style: const TextStyle(fontSize: 12)),
                )),
              ]),
              SwitchListTile(
                title: const Text('Hoạt động'),
                value: active,
                onChanged: (val) => setSt(() => active = val),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                if (code.text.trim().isEmpty) return;
                final payload = Voucher(
                  id: v?.id ?? const Uuid().v4(),
                  code: code.text.trim().toUpperCase(),
                  name: name.text.trim(),
                  discountType: type,
                  discountValue: double.tryParse(value.text) ?? 0,
                  minOrderValue: double.tryParse(minOrder.text) ?? 0,
                  maxDiscount: double.tryParse(maxDiscount.text) ?? 0,
                  startDate: start,
                  endDate: end.isAfter(start) ? end : start,
                  usageLimit: int.tryParse(usageLimit.text) ?? 100,
                  usedCount: v?.usedCount ?? 0,
                  active: active,
                );
                if (v == null) {
                  store.addVoucher(payload);
                } else {
                  store.updateVoucher(payload);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
