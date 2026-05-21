import '../../core/constants/enums.dart';
import '../models/recipe.dart';

List<Recipe> seedRecipes() {
  // Helper tạo công thức nhanh
  Recipe r(String pid, DrinkSize sz, List<List> items) => Recipe(
        id: 'rc-' + pid + '-' + sz.code,
        productId: pid,
        size: sz,
        items: items
            .map((e) => RecipeItem(
                  ingredientId: e[0] as String,
                  quantity: (e[1] as num).toDouble(),
                  unit: e[2] as String,
                ))
            .toList(),
      );

  return [
    // Cafe đen M
    r('p-caphe-den', DrinkSize.m, [
      ['ing-cafe-bot', 20, 'g'],
      ['ing-duong', 10, 'g'],
      ['ing-ly-m', 1, 'cái'],
      ['ing-ong-hut', 1, 'cái'],
      ['ing-nap-ly', 1, 'cái'],
    ]),
    r('p-caphe-den', DrinkSize.l, [
      ['ing-cafe-bot', 25, 'g'], ['ing-duong', 12, 'g'],
      ['ing-ly-l', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Cafe sữa
    r('p-caphe-sua', DrinkSize.m, [
      ['ing-cafe-bot', 18, 'g'], ['ing-sua-dac', 25, 'ml'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Bạc xỉu
    r('p-bac-xiu', DrinkSize.m, [
      ['ing-cafe-bot', 10, 'g'], ['ing-sua-dac', 30, 'ml'],
      ['ing-sua-tuoi', 100, 'ml'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Cappuccino M
    r('p-cappuccino', DrinkSize.m, [
      ['ing-cafe-bot', 20, 'g'], ['ing-sua-tuoi', 150, 'ml'],
      ['ing-ly-m', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Latte M
    r('p-latte', DrinkSize.m, [
      ['ing-cafe-bot', 20, 'g'], ['ing-sua-tuoi', 180, 'ml'],
      ['ing-ly-m', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Trà đào L
    r('p-tra-dao', DrinkSize.l, [
      ['ing-tra-den', 150, 'ml'], ['ing-syrup-dao', 30, 'ml'],
      ['ing-dao-mieng', 40, 'g'], ['ing-duong', 15, 'g'],
      ['ing-ly-l', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    r('p-tra-dao', DrinkSize.m, [
      ['ing-tra-den', 120, 'ml'], ['ing-syrup-dao', 25, 'ml'],
      ['ing-dao-mieng', 30, 'g'], ['ing-duong', 12, 'g'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Trà vải
    r('p-tra-vai', DrinkSize.m, [
      ['ing-tra-den', 120, 'ml'], ['ing-syrup-vai', 25, 'ml'],
      ['ing-duong', 12, 'g'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Trà chanh
    r('p-tra-chanh', DrinkSize.m, [
      ['ing-tra-den', 100, 'ml'], ['ing-duong', 15, 'g'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Trà sữa truyền thống
    r('p-trasua-truyenthong', DrinkSize.m, [
      ['ing-tra-den', 100, 'ml'], ['ing-sua-dac', 40, 'ml'],
      ['ing-tran-chau', 30, 'g'], ['ing-duong', 10, 'g'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Trà sữa matcha
    r('p-trasua-matcha', DrinkSize.m, [
      ['ing-tra-xanh', 8, 'g'], ['ing-sua-tuoi', 150, 'ml'],
      ['ing-duong', 12, 'g'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Soda việt quất
    r('p-soda-vietquat', DrinkSize.m, [
      ['ing-syrup-vai', 30, 'ml'], ['ing-duong', 10, 'g'],
      ['ing-ly-m', 1, 'cái'], ['ing-ong-hut', 1, 'cái'], ['ing-nap-ly', 1, 'cái'],
    ]),
    // Bánh tiramisu
    r('p-banh-tiramisu', DrinkSize.m, [
      ['ing-sua-tuoi', 50, 'ml'],
    ]),
  ];
}
