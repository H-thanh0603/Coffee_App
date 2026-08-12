import '../../core/constants/enums.dart';
import '../models/product.dart';

List<Product> seedProducts() => [
      // === CAFE ===
      Product(
        id: 'p-caphe-den',
        name: 'Cafe đen',
        emoji: '☕',
        imageUrl:
            'https://images.unsplash.com/photo-1514432324607-a09d9b4aefda?w=400&h=400&fit=crop',
        description: 'Cafe phin truyền thống đậm đà, thơm nồng.',
        categoryId: 'cat-cafe',
        basePrice: 25000,
        priceBySize: const {
          DrinkSize.s: 25000,
          DrinkSize.m: 30000,
          DrinkSize.l: 35000,
        },
        availableToppingIds: const ['tp-coffee-jelly', 'tp-pudding'],
      ),
      Product(
        id: 'p-caphe-sua',
        name: 'Cafe sữa',
        emoji: '🥛',
        imageUrl:
            'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&h=400&fit=crop',
        description: 'Cafe phin pha sữa đặc, vị ngọt béo cân bằng.',
        categoryId: 'cat-cafe',
        basePrice: 30000,
        priceBySize: const {
          DrinkSize.s: 30000,
          DrinkSize.m: 35000,
          DrinkSize.l: 40000,
        },
        availableToppingIds: const ['tp-coffee-jelly', 'tp-pudding'],
      ),
      Product(
        id: 'p-bac-xiu',
        name: 'Bạc xỉu',
        emoji: '🤎',
        imageUrl:
            'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=400&h=400&fit=crop',
        description: 'Sữa nhiều cafe ít, vị ngọt béo dịu nhẹ.',
        categoryId: 'cat-cafe',
        basePrice: 32000,
        priceBySize: const {
          DrinkSize.s: 32000,
          DrinkSize.m: 38000,
          DrinkSize.l: 42000,
        },
      ),
      Product(
        id: 'p-cappuccino',
        name: 'Cappuccino',
        emoji: '☕',
        imageUrl:
            'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=400&h=400&fit=crop',
        description: 'Espresso, sữa nóng và lớp foam mịn màng.',
        categoryId: 'cat-cafe',
        basePrice: 45000,
        priceBySize: const {
          DrinkSize.s: 45000,
          DrinkSize.m: 50000,
          DrinkSize.l: 55000,
        },
      ),
      Product(
        id: 'p-latte',
        name: 'Latte',
        emoji: '🍮',
        imageUrl:
            'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&h=400&fit=crop',
        description: 'Espresso pha sữa nóng, foam mỏng, vị nhẹ.',
        categoryId: 'cat-cafe',
        basePrice: 48000,
        priceBySize: const {
          DrinkSize.s: 48000,
          DrinkSize.m: 52000,
          DrinkSize.l: 58000,
        },
      ),
      // === TRÀ TRÁI CÂY ===
      Product(
        id: 'p-tra-dao',
        name: 'Trà đào cam sả',
        emoji: '🍑',
        imageUrl:
            'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&h=400&fit=crop',
        description: 'Trà đen, đào miếng, cam sả tươi mát.',
        categoryId: 'cat-tea-fruit',
        basePrice: 35000,
        priceBySize: const {
          DrinkSize.s: 35000,
          DrinkSize.m: 40000,
          DrinkSize.l: 45000,
        },
        availableToppingIds: const ['tp-peach', 'tp-aloe'],
      ),
      Product(
        id: 'p-tra-vai',
        name: 'Trà vải',
        emoji: '🍒',
        imageUrl:
            'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&h=400&fit=crop',
        description: 'Trà đen ngâm vải tươi, ngọt thanh.',
        categoryId: 'cat-tea-fruit',
        basePrice: 35000,
        priceBySize: const {
          DrinkSize.s: 35000,
          DrinkSize.m: 40000,
          DrinkSize.l: 45000,
        },
        availableToppingIds: const ['tp-aloe'],
      ),
      Product(
        id: 'p-tra-chanh',
        name: 'Trà chanh',
        emoji: '🍋',
        imageUrl:
            'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&h=400&fit=crop',
        description: 'Trà đen, chanh tươi, đường, đá nhiều.',
        categoryId: 'cat-tea-fruit',
        basePrice: 25000,
        priceBySize: const {
          DrinkSize.s: 25000,
          DrinkSize.m: 30000,
          DrinkSize.l: 35000,
        },
      ),
      // === TRÀ SỮA ===
      Product(
        id: 'p-trasua-truyenthong',
        name: 'Trà sữa truyền thống',
        emoji: '🧋',
        imageUrl:
            'https://images.unsplash.com/photo-1525803377221-3e23ea81e215?w=400&h=400&fit=crop',
        description: 'Trà đen pha sữa béo, vị thơm cổ điển.',
        categoryId: 'cat-tea-milk',
        basePrice: 35000,
        priceBySize: const {
          DrinkSize.s: 35000,
          DrinkSize.m: 40000,
          DrinkSize.l: 45000,
        },
        availableToppingIds: const [
          'tp-pearl-black',
          'tp-pearl-white',
          'tp-pudding',
          'tp-cheese',
        ],
      ),
      Product(
        id: 'p-trasua-matcha',
        name: 'Trà sữa matcha',
        emoji: '🍵',
        imageUrl:
            'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?w=400&h=400&fit=crop',
        description: 'Bột matcha Nhật Bản pha sữa béo ngậy.',
        categoryId: 'cat-tea-milk',
        basePrice: 42000,
        priceBySize: const {
          DrinkSize.s: 42000,
          DrinkSize.m: 48000,
          DrinkSize.l: 52000,
        },
        availableToppingIds: const [
          'tp-pearl-black',
          'tp-pudding',
          'tp-cheese',
        ],
      ),
      Product(
        id: 'p-trasua-chocolate',
        name: 'Trà sữa chocolate',
        emoji: '🍫',
        imageUrl:
            'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=400&h=400&fit=crop',
        description: 'Cacao đậm pha sữa, vị ngọt nhẹ.',
        categoryId: 'cat-tea-milk',
        basePrice: 40000,
        priceBySize: const {
          DrinkSize.s: 40000,
          DrinkSize.m: 45000,
          DrinkSize.l: 50000,
        },
        availableToppingIds: const [
          'tp-pearl-black',
          'tp-pudding',
          'tp-cheese',
        ],
      ),
      // === ĐÁ XAY ===
      Product(
        id: 'p-matcha-dax',
        name: 'Matcha đá xay',
        emoji: '🥤',
        imageUrl:
            'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?w=400&h=400&fit=crop',
        description: 'Matcha pha kem tươi đá xay mát lạnh.',
        categoryId: 'cat-ice-blend',
        basePrice: 50000,
        priceBySize: const {
          DrinkSize.s: 50000,
          DrinkSize.m: 55000,
          DrinkSize.l: 60000,
        },
        availableToppingIds: const ['tp-cheese'],
      ),
      Product(
        id: 'p-cookies-dax',
        name: 'Cookies đá xay',
        emoji: '🍪',
        imageUrl:
            'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=400&h=400&fit=crop',
        description: 'Bánh cookies xay nhuyễn với kem tươi và đá.',
        categoryId: 'cat-ice-blend',
        basePrice: 52000,
        priceBySize: const {
          DrinkSize.s: 52000,
          DrinkSize.m: 57000,
          DrinkSize.l: 62000,
        },
        availableToppingIds: const ['tp-cheese'],
      ),
      // === SODA ===
      Product(
        id: 'p-soda-vietquat',
        name: 'Soda việt quất',
        emoji: '🫐',
        imageUrl:
            'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&h=400&fit=crop',
        description: 'Soda mát lạnh kết hợp syrup việt quất.',
        categoryId: 'cat-soda',
        basePrice: 38000,
        priceBySize: const {
          DrinkSize.s: 38000,
          DrinkSize.m: 43000,
          DrinkSize.l: 48000,
        },
      ),
      // === BÁNH ===
      Product(
        id: 'p-banh-tiramisu',
        name: 'Bánh tiramisu',
        emoji: '🍰',
        imageUrl:
            'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=400&h=400&fit=crop',
        description: 'Bánh tiramisu Ý mềm mịn vị cafe.',
        categoryId: 'cat-cake',
        basePrice: 45000,
        priceBySize: const {DrinkSize.m: 45000},
      ),
      Product(
        id: 'p-banh-croissant',
        name: 'Bánh croissant',
        emoji: '🥐',
        imageUrl:
            'https://images.unsplash.com/photo-1555507036-ab1f4038024a?w=400&h=400&fit=crop',
        description: 'Bánh sừng bò bơ Pháp giòn tan.',
        categoryId: 'cat-cake',
        basePrice: 30000,
        priceBySize: const {DrinkSize.m: 30000},
      ),
    ];
