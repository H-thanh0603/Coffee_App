import '../../core/constants/enums.dart';

class Voucher {
  final String id;
  final String code;
  final String name;
  final DiscountType discountType;
  final double discountValue;
  final double minOrderValue;
  final double maxDiscount;
  final DateTime startDate;
  final DateTime endDate;
  final int usageLimit;
  int usedCount;
  bool active;

  Voucher({
    required this.id,
    required this.code,
    required this.name,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxDiscount = 0,
    required this.startDate,
    required this.endDate,
    this.usageLimit = 1000,
    this.usedCount = 0,
    this.active = true,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isStartedAndValid =>
      DateTime.now().isAfter(startDate) && !isExpired && active;
  bool get isAvailable => isStartedAndValid && usedCount < usageLimit;

  double calcDiscount(double subtotal) {
    if (subtotal < minOrderValue) return 0;
    double d;
    if (discountType == DiscountType.percent) {
      d = subtotal * discountValue / 100;
      if (maxDiscount > 0 && d > maxDiscount) d = maxDiscount;
    } else {
      d = discountValue;
    }
    if (d > subtotal) d = subtotal;
    return d;
  }
}
