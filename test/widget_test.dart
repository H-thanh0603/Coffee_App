import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcafe/app.dart';
import 'package:smartcafe/core/theme/theme_provider.dart';
import 'package:smartcafe/data/services/data_store.dart';
import 'package:smartcafe/features/auth/auth_provider.dart';
import 'package:smartcafe/features/cart/cart_provider.dart';

void main() {
  testWidgets('App khởi động đến màn Login (chưa đăng nhập)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DataStore();
    await store.init();
    final themeProvider = ThemeProvider();
    final auth = AuthProvider(store);
    await auth.restoreSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: const SmartCafeApp(),
      ),
    );

    // Vòng redirect '/' -> '/login' chạy qua vài khung hình
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Đang hiển thị màn đăng nhập
    expect(find.text('SmartCafe'), findsWidgets);
    expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
    expect(find.text('Đăng nhập', skipOffstage: false), findsWidgets);
  });
}