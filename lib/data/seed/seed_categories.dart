import '../models/category.dart';

List<ProductCategory> seedCategories() => [
      ProductCategory(id: 'cat-cafe', name: 'Cafe', icon: '☕'),
      ProductCategory(id: 'cat-tea-milk', name: 'Trà sữa', icon: '🧋'),
      ProductCategory(id: 'cat-tea-fruit', name: 'Trà trái cây', icon: '🍑'),
      ProductCategory(id: 'cat-ice-blend', name: 'Đá xay', icon: '🧊'),
      ProductCategory(id: 'cat-soda', name: 'Soda', icon: '🥤'),
      ProductCategory(id: 'cat-cake', name: 'Bánh ngọt', icon: '🍰'),
    ];
