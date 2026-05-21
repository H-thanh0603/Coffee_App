import '../../core/constants/enums.dart';

class StockTransaction {
  final String id;
  final String ingredientId;
  final String ingredientName;
  final StockTxType type;
  final double quantity;
  final String unit;
  final String note;
  final String createdBy;
  final DateTime createdAt;

  StockTransaction({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.type,
    required this.quantity,
    required this.unit,
    this.note = '',
    this.createdBy = 'system',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
