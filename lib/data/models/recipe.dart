import '../../core/constants/enums.dart';

class RecipeItem {
  final String ingredientId;
  final double quantity;
  final String unit;

  RecipeItem({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });
}

class Recipe {
  final String id;
  final String productId;
  final DrinkSize size;
  final List<RecipeItem> items;

  Recipe({
    required this.id,
    required this.productId,
    required this.size,
    required this.items,
  });
}
