import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/services/data_store.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DataStore();
  await store.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => AuthProvider(store)),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const SmartCafeApp(),
    ),
  );
}
