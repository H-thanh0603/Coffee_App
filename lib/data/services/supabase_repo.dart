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
class SupabaseRepo {
  final sb.SupabaseClient? client; // null khi chưa có project/key
  final List<SupabaseOp> _pending = [];
  bool _draining = false;

  /// Total ops applied since app start (test spy).
  @visibleForTesting
  int appliedCount = 0;

  /// Total ops that failed and were dropped (test spy).
  @visibleForTesting
  int failedCount = 0;

  /// Callback khi 1 op fail sau retries (log / UI hint).
  void Function(SupabaseOp op, Object error)? onOpFailed;

  SupabaseRepo({this.client, this.onOpFailed});

  bool get enabled => client != null;

  /// Thêm op vào queue, drain async (fire-and-forget).
  void enqueue(SupabaseOp op) {
    _pending.add(op);
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final op = _pending.removeAt(0);
        final ok = await _apply(op);
        if (!ok) {
          failedCount++;
          onOpFailed?.call(op, Exception('rpc failed'));
        } else {
          appliedCount++;
        }
      }
    } finally {
      _draining = false;
    }
  }

  String _snake(String s) => s.replaceAllMapped(
      RegExp(r'[A-Z]'), (m) => '_' + m.group(0)!.toLowerCase());

  Future<bool> _apply(SupabaseOp op) async {
    final c = client;
    if (c == null) return true; // no backend configured -> no-op
    try {
      // record ops: upsert_<table> / delete_<table>
      if (op.type.startsWith('upsert_')) {
        final table = op.type.substring('upsert_'.length);
        await c.from(table).upsert(_rowFor(op));
        return true;
      }
      if (op.type.startsWith('delete_')) {
        final table = op.type.substring('delete_'.length);
        await c
            .from(table)
            .delete()
            .eq('id', op.payload['id'] as String);
        return true;
      }
      final fn = _rpcFor(op.type);
      if (fn != null) {
        await c.rpc(fn, params: _snakeKeys(op.payload));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SupabaseRepo: op ${op.type} fail: $e');
      return false;
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
      ];
      final data = <String, List<Map<String, dynamic>>>{};
      for (final t in tables) {
        final r = await c.from(t).select().limit(5000);
        data[t] = (r as List)
            .map((e) => _camelKeys(Map<String, dynamic>.from(e)))
            .toList();
      }
      _lastPull = data;
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
                  .map((e) => e is Map
                      ? _camelKeys(Map<String, dynamic>.from(e))
                      : e)
                  .toList()
              : v);
    });
    return out;
  }

  Map<String, List<Map<String, dynamic>>>? _lastPull;

  Map<String, List<Map<String, dynamic>>>? get lastPull => _lastPull;

  /// Serialize pending ops để persist qua SharedPreferences (offline replay).
  String encodePending() => jsonEncode(_pending.map((o) => o.toJson()).toList());

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
    } catch (_) {}
  }
}
