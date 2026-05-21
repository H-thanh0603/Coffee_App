import '../models/category.dart';

List<Category> seedCategories() => [
      Category(id: 'cat-cafe', name: 'Cafe', icon: '☕'),
      Category(id: 'cat-tea-milk', name: 'Trà sữa', icon: '🧋'),
      Category(id: 'cat-tea-fruit', name: 'Trà trái cây', icon: '🍑'),
      Category(id: 'cat-ice-blend', name: 'Đá xay', icon: '🧊'),
      Category(id: 'cat-soda', name: 'Soda', icon: '🥤'),
      Category(id: 'cat-cake', name: 'Bánh ngọt', icon: '🍰'),
    ];
