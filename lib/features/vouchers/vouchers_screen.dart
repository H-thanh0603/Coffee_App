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
          IconButton(icon: const Icon(Icons.add), onPressed: () => _add(context, store)),
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
                      v.name + '\n' +
                      (v.discountType == DiscountType.percent
                          ? 'Giảm ' + v.discountValue.toStringAsFixed(0) + '%'
                          : 'Giảm ' + Fmt.money(v.discountValue)) +
                      ' • Đã dùng ' + v.usedCount.toString() + '/' + v.usageLimit.toString() +
                      '\nHSD: ' + Fmt.date(v.endDate),
                    ),
                    isThreeLine: true,
                    trailing: Switch(
                      value: v.active,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        v.active = val;
                        store.updateVoucher(v);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _add(BuildContext ctx, DataStore store) {
    final code = TextEditingController();
    final name = TextEditingController();
    final value = TextEditingController(text: '10');
    DiscountType type = DiscountType.percent;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (sCtx, setSt) => AlertDialog(
        title: const Text('Thêm voucher'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã voucher')),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên')),
          TextField(controller: value, decoration: const InputDecoration(labelText: 'Giá trị'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ChoiceChip(
              label: const Text('Phần trăm'),
              selected: type == DiscountType.percent,
              onSelected: (_) => setSt(() => type = DiscountType.percent),
              selectedColor: AppColors.primary,
            )),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(
              label: const Text('Số tiền'),
              selected: type == DiscountType.amount,
              onSelected: (_) => setSt(() => type = DiscountType.amount),
              selectedColor: AppColors.primary,
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () {
            if (code.text.trim().isEmpty) return;
            final now = DateTime.now();
            store.addVoucher(Voucher(
              id: const Uuid().v4(),
              code: code.text.trim().toUpperCase(),
              name: name.text.trim(),
              discountType: type,
              discountValue: double.tryParse(value.text) ?? 0,
              startDate: now,
              endDate: now.add(const Duration(days: 30)),
            ));
            Navigator.pop(ctx);
          }, child: const Text('Thêm')),
        ],
      ),
    ));
  }
}
