import 'package:intl/intl.dart';

/// Helpers cho format tiền VND, ngày, giờ
class Fmt {
  static final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _shortDate = DateFormat('dd/MM');

  static String money(num value) => _money.format(value);
  static String date(DateTime d) => _dateFmt.format(d);
  static String time(DateTime d) => _timeFmt.format(d);
  static String dateTime(DateTime d) => _dtFmt.format(d);
  static String shortDate(DateTime d) => _shortDate.format(d);

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return _dateFmt.format(d);
  }

  static String orderCode(int n) =>
      'OD${DateTime.now().year}${n.toString().padLeft(5, "0")}';
}
