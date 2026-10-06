import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:smartcafe/data/services/supabase_repo.dart';

/// SupabaseRepo test không cần backend thật: client null -> no-op drain;
/// applyOverride giả lập lỗi/thành công để test retry + dead-letter.
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

  test('lỗi tạm thời -> tự retry rồi thành công, không vào dead-letter',
      () async {
    final repo = SupabaseRepo(maxRetries: 3, retryDelay: Duration.zero);
    var calls = 0;
    repo.applyOverride = (op) async {
      calls++;
      return calls < 3
          ? const FakeApplyResult.fail()
          : const FakeApplyResult.ok();
    };
    repo.enqueue(SupabaseOp('o1', 'stock_in', {'p_id': 'tx1'}));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls, 3);
    expect(repo.appliedCount, 1);
    expect(repo.failedCount, 0);
    expect(repo.failedOps, isEmpty);
    expect(repo.pendingCount, 0);
  });

  test(
      'hết retries -> vào dead-letter, gọi onOpFailed, còn trong queue persist',
      () async {
    final repo = SupabaseRepo(maxRetries: 1, retryDelay: Duration.zero);
    final failures = <String>[];
    repo.onOpFailed = (op, err) => failures.add(op.id);
    repo.applyOverride = (op) async => const FakeApplyResult.fail();
    repo.enqueue(SupabaseOp('o1', 'create_order', {'p': 1}));
    repo.enqueue(SupabaseOp('o2', 'pay_order', {'p': 2}));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(repo.failedCount, 2);
    expect(failures, ['o1', 'o2']);
    expect(repo.failedOps.map((o) => o.id), ['o1', 'o2']);
    expect(repo.pendingCount, 0);
    // encodePending giữ cả dead-letter -> persist không mất dữ liệu
    final persisted = jsonDecode(repo.encodePending()) as List;
    expect(persisted.length, 2);
  });

  test('retryFailed: dead-letter quay lại queue và áp thành công', () async {
    final repo = SupabaseRepo(maxRetries: 0, retryDelay: Duration.zero);
    var fail = true;
    repo.applyOverride = (op) async =>
        fail ? const FakeApplyResult.fail() : const FakeApplyResult.ok();
    repo.enqueue(SupabaseOp('o1', 'stock_out', {'p_id': 'tx1'}));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.failedOps.length, 1);

    fail = false;
    repo.retryFailed();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.appliedCount, 1);
    expect(repo.failedOps, isEmpty);
    expect(repo.pendingCount, 0);
  });

  test('onOpApplied nhận kết quả RPC (order_code server sinh)', () async {
    final repo = SupabaseRepo(maxRetries: 0, retryDelay: Duration.zero);
    final applied = <String, Object?>{};
    repo.onOpApplied = (op, result) => applied[op.id] = result;
    repo.applyOverride = (op) async => op.type == 'create_order'
        ? const FakeApplyResult.ok('OD202600001')
        : const FakeApplyResult.ok();
    repo.enqueue(SupabaseOp('ord1', 'create_order', {}));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(applied['ord1'], 'OD202600001');
  });

  test('onQueueChanged được gọi khi queue thay đổi (persist hook)', () async {
    final repo = SupabaseRepo(maxRetries: 0, retryDelay: Duration.zero);
    var changes = 0;
    repo.onQueueChanged = () => changes++;
    repo.applyOverride = (op) async => const FakeApplyResult.ok();
    repo.enqueue(SupabaseOp('o1', 'stock_in', {}));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(changes, 1); // 1 lần sau khi drain xong op
  });
}
