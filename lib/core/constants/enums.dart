/// Vai trò người dùng
enum UserRole {
  admin('admin', 'Chủ quán'),
  cashier('cashier', 'Thu ngân'),
  barista('barista', 'Pha chế'),
  waiter('waiter', 'Phục vụ'),
  customer('customer', 'Khách hàng');

  final String code;
  final String label;
  const UserRole(this.code, this.label);

  static UserRole fromCode(String code) =>
      UserRole.values.firstWhere((e) => e.code == code,
          orElse: () => UserRole.customer);
}

/// Trạng thái đơn hàng
enum OrderStatus {
  pending('pending', 'Chờ xác nhận'),
  confirmed('confirmed', 'Đã xác nhận'),
  preparing('preparing', 'Đang pha chế'),
  ready('ready', 'Hoàn thành'),
  served('served', 'Đã giao'),
  paid('paid', 'Đã thanh toán'),
  cancelled('cancelled', 'Đã hủy');

  final String code;
  final String label;
  const OrderStatus(this.code, this.label);

  static OrderStatus fromCode(String code) =>
      OrderStatus.values.firstWhere((e) => e.code == code,
          orElse: () => OrderStatus.pending);
}

/// Loại đơn
enum OrderType {
  dineIn('dine_in', 'Tại quán'),
  takeaway('takeaway', 'Mang đi');

  final String code;
  final String label;
  const OrderType(this.code, this.label);
}

/// Trạng thái thanh toán
enum PaymentStatus {
  unpaid('unpaid', 'Chưa thanh toán'),
  paid('paid', 'Đã thanh toán'),
  refunded('refunded', 'Đã hoàn tiền');

  final String code;
  final String label;
  const PaymentStatus(this.code, this.label);
}

/// Phương thức thanh toán
enum PaymentMethod {
  cash('cash', 'Tiền mặt'),
  transfer('transfer', 'Chuyển khoản'),
  ewallet('ewallet', 'Ví điện tử'),
  qr('qr', 'QR Banking');

  final String code;
  final String label;
  const PaymentMethod(this.code, this.label);
}

/// Trạng thái bàn
enum TableStatus {
  empty('empty', 'Trống'),
  serving('serving', 'Đang phục vụ'),
  waiting('waiting', 'Chờ thanh toán'),
  reserved('reserved', 'Đã đặt trước'),
  needsClean('needs_clean', 'Cần dọn');

  final String code;
  final String label;
  const TableStatus(this.code, this.label);
}

/// Size đồ uống
enum DrinkSize {
  s('S', 'Nhỏ'),
  m('M', 'Vừa'),
  l('L', 'Lớn');

  final String code;
  final String label;
  const DrinkSize(this.code, this.label);
}

/// Mức đường
enum SugarLevel {
  zero(0, '0%'),
  low(30, '30%'),
  half(50, '50%'),
  high(70, '70%'),
  full(100, '100%');

  final int percent;
  final String label;
  const SugarLevel(this.percent, this.label);
}

/// Mức đá
enum IceLevel {
  none('none', 'Không đá'),
  low('low', 'Ít đá'),
  normal('normal', 'Bình thường'),
  high('high', 'Nhiều đá');

  final String code;
  final String label;
  const IceLevel(this.code, this.label);
}

/// Hạng khách hàng
enum CustomerRank {
  bronze('bronze', 'Đồng', 0xFFCD7F32),
  silver('silver', 'Bạc', 0xFF94A3B8),
  gold('gold', 'Vàng', 0xFFF59E0B),
  diamond('diamond', 'Kim cương', 0xFF06B6D4);

  final String code;
  final String label;
  final int colorValue;
  const CustomerRank(this.code, this.label, this.colorValue);

  static CustomerRank fromPoints(int points) {
    if (points >= 700) return diamond;
    if (points >= 300) return gold;
    if (points >= 100) return silver;
    return bronze;
  }
}

/// Loại giảm giá
enum DiscountType {
  percent('percent', 'Phần trăm'),
  amount('amount', 'Số tiền');

  final String code;
  final String label;
  const DiscountType(this.code, this.label);
}

/// Loại giao dịch kho
enum StockTxType {
  inbound('in', 'Nhập kho'),
  outbound('out', 'Xuất kho'),
  consumed('consumed', 'Tiêu thụ');

  final String code;
  final String label;
  const StockTxType(this.code, this.label);
}
