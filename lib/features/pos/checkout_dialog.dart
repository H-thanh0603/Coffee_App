import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/data_store.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import 'qr_bank_form.dart';
import 'receipt_screen.dart';
import 'vietqr.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});
  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  ShopBank? _bank;
  bool _bankLoaded = false;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    if (!_bankLoaded) {
      _bankLoaded = true;
      ShopBank.load().then((b) {
        if (mounted) setState(() => _bank = b);
      });
    }

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
                  _QrPayBox(amount: cart.total, bank: _bank),
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

/// QR thanh toán đúng số tiền. Chưa cấu hình TK quán -> hiện nút mở Cài đặt.
class _QrPayBox extends StatefulWidget {
  final double amount;
  final ShopBank? bank;
  const _QrPayBox({required this.amount, required this.bank});
  @override
  State<_QrPayBox> createState() => _QrPayBoxState();
}

class _QrPayBoxState extends State<_QrPayBox> {
  ShopBank? _bank;

  @override
  void initState() {
    super.initState();
    _bank = widget.bank;
  }

  @override
  Widget build(BuildContext context) {
    final b = _bank;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        if (b == null || !b.isConfigured) ...[
          const Icon(Icons.account_balance, size: 40, color: AppColors.warning),
          const SizedBox(height: 8),
          Text('Chưa cấu hình tài khoản nhận tiền',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrBankForm()),
              );
              final saved = await ShopBank.load();
              if (mounted) setState(() => _bank = saved);
            },
            child: const Text('Cấu hình ngay'),
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              b.imageUrl(widget.amount.round(),
                  'SMARTCAFE ' + Fmt.money(widget.amount)),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 200,
                height: 200,
                child: Center(child: Text('Không tải được QR')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(b.bankCode + ' • ' + b.account,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          Text(Fmt.money(widget.amount) + ' • Khách quét đúng số tiền',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}


