import '../../core/constants/enums.dart';

class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String emoji;
  final DrinkSize size;
  final List<String> toppingIds;
  final List<String> toppingNames;
  final double toppingsPrice;
  final SugarLevel sugar;
  final IceLevel ice;
  int quantity;
  final double unitPrice;
  final String note;
  String status; // pending / preparing / ready / served

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.size,
    required this.unitPrice,
    this.emoji = '☕',
    this.toppingIds = const [],
    this.toppingNames = const [],
    this.toppingsPrice = 0,
    this.sugar = SugarLevel.full,
    this.ice = IceLevel.normal,
    this.quantity = 1,
    this.note = '',
    this.status = 'pending',
  });

  double get totalPrice => (unitPrice + toppingsPrice) * quantity;

  OrderItem copyWith({int? quantity, String? status}) => OrderItem(
        id: id,
        productId: productId,
        productName: productName,
        emoji: emoji,
        size: size,
        toppingIds: toppingIds,
        toppingNames: toppingNames,
        toppingsPrice: toppingsPrice,
        sugar: sugar,
        ice: ice,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice,
        note: note,
        status: status ?? this.status,
      );
}
