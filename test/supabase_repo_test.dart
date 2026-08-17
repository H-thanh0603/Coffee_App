import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:smartcafe/data/services/supabase_repo.dart';

/// SupabaseRepo test không cần backend thật: client null -> no-op drain.
void main() {
  test('enqueue không backend: op bị drain, không rơi vào pending', () async {
    final repo = SupabaseRepo();
    repo.enqueue(SupabaseOp('o1', 'create_order', {'p': 1}));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.appliedCount, 1); // client null -> _apply trả true no-op
    expect(repo.failedCount, 0);
  });

  test('encodePending -> restorePending replay giữ nguyên payload', () {
    final repo = SupabaseRepo();
    repo.restorePending('''
      [{"id":"o1","type":"create_order",
        "payload":{"total":100,"customerId":"c1"}}]
    ''');
    final decoded = jsonDecode(repo.encodePending()) as List;
    expect(decoded.length, 1);
    expect((decoded[0] as Map)['id'], 'o1');
    expect((decoded[0] as Map)['type'], 'create_order');
    expect(((decoded[0] as Map)['payload'] as Map)['customerId'], 'c1');
  });
}