import '../../core/constants/enums.dart';
import '../models/voucher.dart';

List<Voucher> seedVouchers() {
  final now = DateTime.now();
  return [
    Voucher(
      id: 'v-welcome10',
      code: 'WELCOME10',
      name: 'Chào mừng khách mới',
      discountType: DiscountType.percent,
      discountValue: 10,
      maxDiscount: 30000,
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now.add(const Duration(days: 60)),
      usageLimit: 1000,
      usedCount: 124,
    ),
    Voucher(
      id: 'v-freeship',
      code: 'FREESHIP',
      name: 'Giảm phí giao hàng',
      discountType: DiscountType.amount,
      discountValue: 15000,
      minOrderValue: 50000,
      startDate: now.subtract(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 30)),
      usedCount: 45,
    ),
    Voucher(
      id: 'v-happyhour',
      code: 'HAPPYHOUR',
      name: 'Giảm 20% khung 14h-16h',
      discountType: DiscountType.percent,
      discountValue: 20,
      maxDiscount: 50000,
      minOrderValue: 100000,
      startDate: now.subtract(const Duration(days: 5)),
      endDate: now.add(const Duration(days: 90)),
      usedCount: 67,
    ),
    Voucher(
      id: 'v-member50',
      code: 'MEMBER50',
      name: 'Giảm 50.000đ cho thành viên',
      discountType: DiscountType.amount,
      discountValue: 50000,
      minOrderValue: 200000,
      startDate: now.subtract(const Duration(days: 15)),
      endDate: now.add(const Duration(days: 45)),
      usedCount: 18,
    ),
    Voucher(
      id: 'v-combo20',
      code: 'COMBO20',
      name: 'Giảm 20% combo nước + bánh',
      discountType: DiscountType.percent,
      discountValue: 20,
      maxDiscount: 40000,
      minOrderValue: 80000,
      startDate: now.subtract(const Duration(days: 2)),
      endDate: now.add(const Duration(days: 14)),
      usedCount: 8,
    ),
  ];
}
