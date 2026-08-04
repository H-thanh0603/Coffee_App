import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import 'receipt_screen.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Thanh toán',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _row('Tổng cộng', Fmt.money(cart.total), bold: true),
                const SizedBox(height: 16),
                const Text('Phương thức',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...PaymentMethod.values.map((m) => RadioListTile<PaymentMethod>(
                      value: m,
                      groupValue: _method,
                      onChanged: (v) => setState(() => _method = v!),
                      title: Row(children: [
                        Icon(_iconFor(m), size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(m.label),
                      ]),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    )),
                if (_method == PaymentMethod.qr) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                            child: Text('🔲', style: TextStyle(fontSize: 80))),
                      ),
                      const SizedBox(height: 8),
                      Text('QR Banking demo',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirm,
                      child: const Text('Xác nhận'),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }

  IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:
        return Icons.payments;
      case PaymentMethod.transfer:
        return Icons.account_balance;
      case PaymentMethod.ewallet:
        return Icons.account_balance_wallet;
      case PaymentMethod.qr:
        return Icons.qr_code;
    }
  }

  Widget _row(String label, String value, {bool bold = false}) =>
      Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 18 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.primary)),
      ]);

  void _confirm() {
    final cart = context.read<CartProvider>();
    final store = context.read<DataStore>();
    final auth = context.read<AuthProvider>();

    final order = store.createOrder(
      cashier: auth.currentUser!,
      items: List.from(cart.items),
      orderType: cart.orderType,
      tableId: cart.tableId,
      customerId: cart.customerId,
      voucher: cart.voucher,
      pointsUsed: cart.pointsUsed,
      pointsDiscount: cart.pointsDiscount,
      note: cart.note,
    );
    store.payOrder(order.id, _method);
    cart.clear();

    // Đóng dialog + giỏ hàng, rồi mở màn hóa đơn
    final nav = Navigator.of(context);
    nav.pop(); // dialog
    nav.pop(); // giỏ hàng
    nav.push(MaterialPageRoute(builder: (_) => ReceiptScreen(order: order)));
  }
}
