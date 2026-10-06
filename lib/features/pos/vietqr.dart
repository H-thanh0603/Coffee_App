import 'package:shared_preferences/shared_preferences.dart';

/// Tài khoản ngân hàng của quán để nhận QR VietQR.
/// QR render qua API ảnh chính thức của VietQR (img.vietqr.io) — đúng chuẩn
/// ngân hàng, khỏi tự sinh chuỗi EMV (sai CRC là QR chết).
class ShopBank {
  final String bankCode;
  final String bin;
  final String account;
  final String name;

  const ShopBank({
    required this.bankCode,
    required this.bin,
    required this.account,
    required this.name,
  });

  /// BIN các ngân hàng phổ biến (mã 6 số chuẩn VietQR).
  static const Map<String, String> banks = {
    'Vietcombank': '970436',
    'VietinBank': '970415',
    'BIDV': '970418',
    'Agribank': '970405',
    'Techcombank': '970407',
    'MB Bank': '970422',
    'ACB': '970416',
    'TPBank': '970423',
    'VPBank': '970432',
    'Sacombank': '970403',
  };

  bool get isConfigured => account.isNotEmpty;

  /// URL ảnh QR với đúng số tiền (VND) + nội dung chuyển khoản.
  String imageUrl(int amountVnd, String info) {
    final infoEnc = Uri.encodeComponent(info);
    final nameEnc = Uri.encodeComponent(name);
    return 'https://img.vietqr.io/image/$bin-$account-compact2.png'
        '?amount=$amountVnd&addInfo=$infoEnc&accountName=$nameEnc';
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('smartcafe_qr_bank', bankCode);
    await p.setString('smartcafe_qr_account', account);
    await p.setString('smartcafe_qr_name', name);
  }

  static Future<ShopBank?> load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString('smartcafe_qr_bank');
    final account = p.getString('smartcafe_qr_account') ?? '';
    if (code == null || account.isEmpty) return null;
    return ShopBank(
      bankCode: code,
      bin: banks[code] ?? '',
      account: account,
      name: p.getString('smartcafe_qr_name') ?? '',
    );
  }
}
