import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/auth/auth_gateway.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/theme_provider.dart';
import 'data/services/data_store.dart';
import 'data/services/outbox.dart';
import 'data/services/sync_engine.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (SupabaseConfig.syncEnabled) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  final store = DataStore();
  await store.init();
  AuthProvider auth;
  SyncEngine? engine;
  if (SupabaseConfig.syncEnabled) {
    final outbox = Outbox();
    await outbox.init();
    store.attachOutbox(outbox);
    final client = Supabase.instance.client;
    engine = SyncEngine(outbox: outbox, store: store, client: client);
    engine.start();
    engine.listenAuth(); // auto-update role on login/logout
    auth = AuthProvider.withGateway(AuthGatewaySupabase(client));
    // khôi phục session đã lưu (mở app không cần login lại)
    await auth.restoreSession();
    // Set role cho realtime subscriptions sau khi có auth
    if (auth.role != null) {
      engine.setRole(auth.role!);
    }
  } else {
    auth = AuthProvider(store);
  }
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  runApp(
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
}
