import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'data/services/data_store.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DataStore();
  await store.init();
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => AuthProvider(store)),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const SmartCafeApp(),
    ),
  );
}
