import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Một thao tác chưa đồng bộ lên server. Được lưu trong SharedPreferences
/// (key `smartcafe_outbox_v1`) để không mất khi offline/đóng app.
/// Replay theo thứ tự FIFO bởi SyncEngine. Các loại op map sang RPC:
///   place_order   -> rpc_place_order (idempotent theo orderId)
///   consume_recipe-> rpc_consume_recipe (idempotent theo stock_consumed)
///   pay_order     -> rpc_pay_order (WHERE payment_status='unpaid' -> no-op nếu đã pay)
///   cancel_order  -> rpc_cancel_order (chặn nếu đã thu tiền)
///   move_order    -> rpc_move_order
///   adjust_stock  -> rpc_adjust_stock
class OutboxOp {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OutboxOp({
    String? id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OutboxOp.fromJson(Map<String, dynamic> m) => OutboxOp(
        id: m['id'] as String,
        type: m['type'] as String,
        payload: (m['payload'] as Map).cast<String, dynamic>(),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? ''),
      );
}

/// Hàng đợi outbox bền vững (persist mỗi lần đổi).
class Outbox {
  static const String prefsKey = 'smartcafe_outbox_v1';

  final List<OutboxOp> _pending = [];
  SharedPreferences? _prefs;

  List<OutboxOp> get pending => List.unmodifiable(_pending);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _pending
        ..clear()
        ..addAll(list
            .whereType<Map>()
            .map((e) => OutboxOp.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {
      // corrupt outbox -> bỏ, không chặn app
    }
  }

  Future<void> enqueue(OutboxOp op) async {
    _pending.add(op);
    await _persist();
  }

  Future<void> remove(String id) async {
    _pending.removeWhere((o) => o.id == id);
    await _persist();
  }

  Future<void> clear() async {
    _pending.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
          prefsKey, jsonEncode(_pending.map((o) => o.toJson()).toList()));
    } catch (_) {
      // persist là phụ trợ
    }
  }
}
