class Topping {
  final String id;
  final String name;
  final double price;
  final bool available;

  Topping({
    required this.id,
    required this.name,
    required this.price,
    this.available = true,
  });

  Topping copyWith({String? name, double? price, bool? available}) => Topping(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        available: available ?? this.available,
      );
}
