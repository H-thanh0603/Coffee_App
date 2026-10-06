import 'package:flutter/material.dart';

import 'vietqr.dart';

/// Form nhập tài khoản ngân hàng của quán để render VietQR đúng số tiền.
/// Dùng chung cho checkout dialog và màn Cài đặt.
class QrBankForm extends StatefulWidget {
  const QrBankForm({super.key});
  @override
  State<QrBankForm> createState() => _QrBankFormState();
}

class _QrBankFormState extends State<QrBankForm> {
  String _bank = ShopBank.banks.keys.first;
  final _acc = TextEditingController();
  final _name = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _acc.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      _loaded = true;
      ShopBank.load().then((b) {
        if (b != null && mounted) {
          setState(() {
            _bank = b.bankCode;
            _acc.text = b.account;
            _name.text = b.name;
          });
        }
      });
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản nhận QR')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String>(
          initialValue: _bank,
          decoration: const InputDecoration(labelText: 'Ngân hàng'),
          items: ShopBank.banks.keys
              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
              .toList(),
          onChanged: (v) => setState(() => _bank = v!),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _acc,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tài khoản')),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Tên chủ TK')),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () async {
            if (_acc.text.trim().isEmpty) return;
            await ShopBank(
              bankCode: _bank,
              bin: ShopBank.banks[_bank]!,
              account: _acc.text.trim(),
              name: _name.text.trim(),
            ).save();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ]),
    );
  }
}
