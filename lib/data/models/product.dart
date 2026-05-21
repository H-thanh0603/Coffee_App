import '../../core/constants/enums.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String emoji;
  final String categoryId;
  final double basePrice;
  final Map<DrinkSize, double> priceBySize;
  final List<String> availableToppingIds;
  final bool inStock;
  final bool hidden;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.basePrice,
    this.imageUrl = '',
    this.emoji = '☕',
    Map<DrinkSize, double>? priceBySize,
    List<String>? availableToppingIds,
    this.inStock = true,
    this.hidden = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : priceBySize = priceBySize ?? {DrinkSize.s: basePrice, DrinkSize.m: basePrice + 5000, DrinkSize.l: basePrice + 10000},
        availableToppingIds = availableToppingIds ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double priceFor(DrinkSize size) => priceBySize[size] ?? basePrice;

  Product copyWith({
    String? name,
    String? description,
    String? imageUrl,
    String? emoji,
    String? categoryId,
    double? basePrice,
    Map<DrinkSize, double>? priceBySize,
    List<String>? availableToppingIds,
    bool? inStock,
    bool? hidden,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        emoji: emoji ?? this.emoji,
        categoryId: categoryId ?? this.categoryId,
        basePrice: basePrice ?? this.basePrice,
        priceBySize: priceBySize ?? this.priceBySize,
        availableToppingIds: availableToppingIds ?? this.availableToppingIds,
        inStock: inStock ?? this.inStock,
        hidden: hidden ?? this.hidden,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
