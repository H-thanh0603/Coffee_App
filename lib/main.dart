import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase/supabase.dart' as sb;

import 'app.dart';
import 'core/theme/theme_provider.dart';
import 'data/services/data_store.dart';
import 'data/services/supabase_repo.dart';
import 'features/auth/auth_provider.dart';
import 'features/cart/cart_provider.dart';

/// Tạo Supabase client nếu có --dart-define SUPABASE_URL + SUPABASE_ANON_KEY.
/// Không config = chạy offline/no backend.
SupabaseRepo buildRepo() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isEmpty || anon.isEmpty) return SupabaseRepo();
  final client = sb.SupabaseClient(url, anon);
  return SupabaseRepo(client: client);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DataStore(repo: buildRepo());
  await store.init();
  final auth = AuthProvider(store);
  await auth.restoreSession();
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
