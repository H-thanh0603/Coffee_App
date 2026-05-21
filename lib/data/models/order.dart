import '../../core/constants/enums.dart';
import 'order_item.dart';

class AppOrder {
  final String id;
  final String orderCode;
  final String? tableId;
  final String? tableName;
  final String? customerId;
  final String? customerName;
  final String cashierId;
  final String cashierName;
  final OrderType orderType;
  final List<OrderItem> items;
  final double subtotal;
  final double discount;
  final String? voucherCode;
  final double total;
  final PaymentMethod? paymentMethod;
  final PaymentStatus paymentStatus;
  OrderStatus orderStatus;
  final String note;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;

  AppOrder({
    required this.id,
    required this.orderCode,
    required this.cashierId,
    required this.cashierName,
    required this.orderType,
    required this.items,
    required this.subtotal,
    required this.total,
    this.tableId,
    this.tableName,
    this.customerId,
    this.customerName,
    this.discount = 0,
    this.voucherCode,
    this.paymentMethod,
    this.paymentStatus = PaymentStatus.unpaid,
    this.orderStatus = OrderStatus.pending,
    this.note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get itemCount => items.fold<int>(0, (s, e) => s + e.quantity);

  Duration get age => DateTime.now().difference(createdAt);

  AppOrder copyWith({
    OrderStatus? orderStatus,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    DateTime? completedAt,
  }) =>
      AppOrder(
        id: id,
        orderCode: orderCode,
        tableId: tableId,
        tableName: tableName,
        customerId: customerId,
        customerName: customerName,
        cashierId: cashierId,
        cashierName: cashierName,
        orderType: orderType,
        items: items,
        subtotal: subtotal,
        discount: discount,
        voucherCode: voucherCode,
        total: total,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        orderStatus: orderStatus ?? this.orderStatus,
        note: note,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        completedAt: completedAt ?? this.completedAt,
      );
}
