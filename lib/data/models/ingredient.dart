class Ingredient {
  final String id;
  final String name;
  final String unit;
  double currentStock;
  final double minStock;
  final double costPerUnit;
  final String supplier;
  final DateTime? expiredDate;
  final bool active;
  final DateTime createdAt;
  DateTime updatedAt;

  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.costPerUnit,
    this.supplier = '',
    this.expiredDate,
    this.active = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLow => currentStock <= minStock;
  bool get isCritical => currentStock <= minStock * 0.5;
  bool get isExpiringSoon =>
      expiredDate != null &&
      expiredDate!.difference(DateTime.now()).inDays <= 7 &&
      expiredDate!.isAfter(DateTime.now());
  bool get isExpired =>
      expiredDate != null && expiredDate!.isBefore(DateTime.now());
}
