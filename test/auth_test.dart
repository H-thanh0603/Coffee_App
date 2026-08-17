import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcafe/data/services/data_store.dart';
import 'package:smartcafe/features/auth/auth_provider.dart';

void main() {
  late DataStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = DataStore();
    await store.init();
  });

  group('AuthProvider mock (không backend)', () {
    test('restoreSession không backend -> trạng thái logged-out + restored', () async {
      final auth = AuthProvider(store);
      expect(auth.restored, isFalse);
      await auth.restoreSession();
      expect(auth.restored, isTrue);
      expect(auth.isLoggedIn, isFalse);
    });

    test('login của cashier -> role cashier, logout -> hết session', () async {
      final auth = AuthProvider(store);
      final err = await auth.login('cashier@smartcafe.com', '123456');
      expect(err, isNull);
      expect(auth.role?.name, 'cashier');
      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
    });
  });
}