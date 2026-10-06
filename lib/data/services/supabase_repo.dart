import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart' as sb;

/// Một mutation đã xảy ra cục bộ, cần áp lên server.
/// Idempotent: RPC server re-check guard nên replay an toàn.
class SupabaseOp {
  final String id; // uuid của entity / tx
  final String type; // 'create_order' | 'pay_order' | 'cancel_order' | ...
  final Map<String, dynamic> payload;

  SupabaseOp(this.id, this.type, this.payload);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
      };
}

/// Writer duy nhất lên Supabase. DataStore giữ sync-cache optimistic,
/// mỗi mutation enqueue 1 op, drain tuần tự gọi RPC.
///
/// Queue bền vững: op fail sau [maxRetries] lần rơi vào dead-letter
/// ([failedOps]) chứ không bị xóa; DataStore persist cả queue lẫn
/// dead-letter xuống local db và replay khi mở lại app ([restorePending]).
class SupabaseRepo {
  final sb.SupabaseClient? client; // null khi chưa có project/key
  final int maxRetries; // số lần thử lại 1 op khi lỗi (network/vắng máy chủ)
  final Duration retryDelay; // backoff giữa các lần thử

  final List<SupabaseOp> _pending = [];
  final List<SupabaseOp> _failed = [];
  bool _draining = false;

  /// Total ops applied since app start (test spy).
  @visibleForTesting
  int appliedCount = 0;

  /// Total ops that failed permanently and moved to dead-letter (test spy).
  @visibleForTesting
  int failedCount = 0;

  /// Callback khi 1 op fail sau retries -> UI cảnh báo.
  void Function(SupabaseOp op, Object error)? onOpFailed;

  /// Callback khi 1 op áp thành công kèm kết quả RPC
  /// (vd create_order trả về order_code do server sinh).
  void Function(SupabaseOp op, Object? result)? onOpApplied;

  /// Callback mỗi khi queue/dead-letter thay đổi -> DataStore persist.
  void Function()? onQueueChanged;

  /// Realtime channel đang mở (null khi chưa subscribe).
  sb.RealtimeChannel? _channel;

  /// Test seam: chặn _apply để giả lập thành công/lỗi mà không cần backend.
  /// Trả null = dùng client thật.
  @visibleForTesting
  Future<FakeApplyResult?> Function(SupabaseOp op)? applyOverride;

  SupabaseRepo({
    this.client,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 250),
  });

  bool get enabled => client != null;

  /// Ops đang chờ gửi server.
  int get pendingCount => _pending.length;

  /// Ops fail sau retries — giữ lại để [retryFailed], không mất dữ liệu.
  List<SupabaseOp> get failedOps => List.unmodifiable(_failed);

  /// Thêm op vào queue, drain async (fire-and-forget).
  void enqueue(SupabaseOp op) {
    _pending.add(op);
    _drain();
  }

  /// Đưa các op dead-letter trở lại đầu queue và drain.
  void retryFailed() {
    if (_failed.isEmpty) return;
    _pending.insertAll(0, _failed);
    _failed.clear();
    onQueueChanged?.call();
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final op = _pending.removeAt(0);
        var ok = false;
        Object? lastError;
        for (var attempt = 0; attempt <= maxRetries; attempt++) {
          if (attempt > 0 && retryDelay > Duration.zero) {
            await Future<void>.delayed(retryDelay * attempt);
          }
          try {
            final result = await _apply(op);
            ok = result.ok;
            lastError = result.error;
            if (ok) {
              if (result.value != null) onOpApplied?.call(op, result.value);
              break;
            }
          } catch (e) {
            lastError = e;
          }
        }
        if (ok) {
          appliedCount++;
        } else {
          // Hết retries: đẩy vào dead-letter thay vì xóa — replay khi thử lại
          // hoặc khi mở lại app (restorePending).
          failedCount++;
          _failed.add(op);
          onOpFailed?.call(op, lastError ?? Exception('rpc failed'));
        }
        onQueueChanged?.call();
      }
    } finally {
      _draining = false;
    }
  }

  String _snake(String s) => s.replaceAllMapped(
      RegExp(r'[A-Z]'), (m) => '_' + m.group(0)!.toLowerCase());

  Future<_ApplyResult> _apply(SupabaseOp op) async {
    final override = applyOverride;
    if (override != null) {
      final fake = await override(op);
      if (fake == null) return const _ApplyResult.ok(null);
      return fake.ok
          ? _ApplyResult.ok(fake.value)
          : const _ApplyResult.fail('fake failure');
    }
    final c = client;
    if (c == null) {
      return const _ApplyResult.ok(null); // no backend configured -> no-op
    }
    try {
      // record ops: upsert_<table> / delete_<table>
      if (op.type.startsWith('upsert_')) {
        final table = op.type.substring('upsert_'.length);
        await c.from(table).upsert(_rowFor(op));
        return const _ApplyResult.ok(null);
      }
      if (op.type.startsWith('delete_')) {
        final table = op.type.substring('delete_'.length);
        await c.from(table).delete().eq('id', op.payload['id'] as String);
        return const _ApplyResult.ok(null);
      }
      final fn = _rpcFor(op.type);
      if (fn != null) {
        final res = await c.rpc(fn, params: _snakeKeys(op.payload));
        return _ApplyResult.ok(res);
      }
      return const _ApplyResult.fail('unknown op type');
    } catch (e) {
      debugPrint('SupabaseRepo: op ${op.type} fail: $e');
      return _ApplyResult.fail(e);
    }
  }

  Map<String, dynamic> _snakeKeys(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) => out[_snake(k)] = _deepEncode(v));
    return out;
  }

  /// Chuyển enum-map/list + nested struct thành JSON-safe (string/list/map).
  dynamic _deepEncode(dynamic v) {
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((k, val) => out[k.toString()] = _deepEncode(val));
      return out;
    }
    if (v is List) return v.map(_deepEncode).toList();
    if (v is DateTime) return v.toIso8601String();
    return v;
  }

  /// Row cho upsert: snake keys + id tách riêng, flatten priceBySize.
  Map<String, dynamic> _rowFor(SupabaseOp op) {
    final row = _snakeKeys(Map<String, dynamic>.from(op.payload['row'] as Map));
    // price_by_size: {'m': 30000, 'l': 35000} (key 's/m/l')
    final pbs = row['price_by_size'];
    if (pbs is Map) row['price_by_size'] = pbs;
    return row;
  }

  static String? _rpcFor(String type) {
    switch (type) {
      case 'create_order':
        return 'create_order_v2';
      case 'pay_order':
        return 'pay_order_v2';
      case 'consume_recipe':
        return 'consume_recipe_v2';
      case 'cancel_order':
        return 'cancel_order_v2';
      case 'move_order':
        return 'move_order_v2';
      case 'merge_tables':
        return 'merge_tables_v2';
      case 'save_recipe':
        return 'save_recipe_v2';
      case 'stock_in':
        return 'stock_in_v2';
      case 'stock_out':
        return 'stock_out_v2';
      default:
        return null;
    }
  }

  // ===== REALTIME =====
  /// Theo dõi thay đổi postgres trên các bảng, đẩy qua [onDirty] ->
  /// DataStore debounce rồi refresh từ server.
  void subscribeRealtime(
    List<String> tables,
    void Function(String table) onDirty,
  ) {
    final c = client;
    if (c == null || _channel != null) return;
    final ch = c.channel('smartcafe_rt');
    for (final t in tables) {
      ch.onPostgresChanges(
        event: sb.PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        callback: (sb.PostgresChangePayload payload) => onDirty(t),
      );
    }
    ch.subscribe();
    _channel = ch;
  }

  void unsubscribeRealtime() {
    final ch = _channel;
    if (ch == null) return;
    client?.removeChannel(ch);
    _channel = null;
  }

  // ===== SERVER PULL =====
  /// Pull toàn bộ data từ server về local lists (refresh manual).
  /// [seedFrom] optional: tự seed nếu DB trống (chưa có migration).
  Future<bool> refresh() async {
    final c = client;
    if (c == null) return false;
    try {
      const tables = [
        'categories',
        'toppings',
        'products',
        'tables',
        'customers',
        'ingredients',
        'recipes',
        'recipe_items',
        'vouchers',
        'orders',
        'order_items',
        'notifications',
        'shifts',
        'reservations',
      ];
      // ponytail: pull song song thay vì tuần tự; bảng chưa migrate thì
      // bỏ qua (giữ local) thay vì fail cả pull.
      final results = await Future.wait(tables.map((t) async {
        try {
          final r = await c.from(t).select().limit(5000);
          return MapEntry(
              t,
              (r as List)
                  .map((e) => _camelKeys(Map<String, dynamic>.from(e)))
                  .toList());
        } catch (e) {
          debugPrint('SupabaseRepo: skip pull $t: $e');
          return MapEntry(t, <Map<String, dynamic>>[]);
        }
      }));
      _lastPull = Map.fromEntries(results);
      return true;
    } catch (e) {
      debugPrint('SupabaseRepo: refresh fail: $e');
      return false;
    }
  }

  static Map<String, dynamic> _camelKeys(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      final parts = k.split('_');
      final camel = parts.first +
          parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
      out[camel] = v is Map
          ? _camelKeys(Map<String, dynamic>.from(v))
          : (v is List
              ? v
                  .map((e) =>
                      e is Map ? _camelKeys(Map<String, dynamic>.from(e)) : e)
                  .toList()
              : v);
    });
    return out;
  }

  Map<String, List<Map<String, dynamic>>>? _lastPull;

  Map<String, List<Map<String, dynamic>>>? get lastPull => _lastPull;

  /// Serialize pending + dead-letter ops để persist (offline replay).
  String encodePending() =>
      jsonEncode([..._pending, ..._failed].map((o) => o.toJson()).toList());

  void restorePending(String raw) {
    try {
      final arr = jsonDecode(raw);
      if (arr is! List) return;
      for (final e in arr) {
        final m = Map<String, dynamic>.from(e as Map);
        _pending.add(SupabaseOp(
          m['id'] as String,
          m['type'] as String,
          Map<String, dynamic>.from(m['payload'] as Map),
        ));
      }
    } catch (e) {
      debugPrint('SupabaseRepo: restorePending fail: $e');
    }
  }
}

class _ApplyResult {
  final bool ok;
  final Object? value;
  final Object? error;
  const _ApplyResult(this.ok, [this.value, this.error]);
  const _ApplyResult.ok(this.value) : error = null;
  const _ApplyResult.fail(this.error) : value = null;
}

/// Kết quả _apply mô phỏng, dùng với [SupabaseRepo.applyOverride] trong test.
class FakeApplyResult {
  final bool ok;
  final Object? value;
  const FakeApplyResult.ok([this.value]) : ok = true;
  const FakeApplyResult.fail()
      : ok = false,
        value = null;
}
