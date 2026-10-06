import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Local persistence key-value dùng cho snapshot DataStore + op queue.
///
/// Mobile: SQLite qua sqflite — thay cho việc nhét toàn bộ state vào 1
/// chuỗi JSON của SharedPreferences (giới hạn kích thước, không
/// transactional, chậm dần khi dữ liệu lớn). Web không có SQLite ->
/// fallback SharedPreferences; sqflite chỉ được chạm trên nền io.
abstract class LocalDb {
  Future<void> init();
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Chọn backend theo nền: SQLite trên mobile, prefs trên web.
  /// Mobile nếu SQLite lỗi lúc mở (vd test VM không có plugin) -> fallback prefs.
  static LocalDb create() => kIsWeb ? PrefsLocalDb() : _FallbackLocalDb();
}

/// SQLite thử trước, hỏng thì dùng prefs (giữ app chạy được).
class _FallbackLocalDb implements LocalDb {
  LocalDb? _active;
  bool _triedInit = false;

  @override
  Future<void> init() async {
    if (_triedInit) return;
    _triedInit = true;
    try {
      final db = SqliteLocalDb();
      await db.init();
      _active = db;
    } catch (e) {
      debugPrint('LocalDb: sqlite init fail, fallback prefs: $e');
      final prefs = PrefsLocalDb();
      await prefs.init();
      _active = prefs;
    }
  }

  LocalDb get _db {
    final db = _active;
    if (db == null) {
      throw StateError('LocalDb.init() chưa được gọi hoặc đã fail');
    }
    return db;
  }

  @override
  Future<String?> read(String key) async =>
      _active == null ? null : _db.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (_active != null) await _db.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    if (_active != null) await _db.delete(key);
  }
}

/// Fallback web + môi trường test: đóng gói SharedPreferences.
class PrefsLocalDb implements LocalDb {
  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> read(String key) async => _prefs?.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs?.remove(key);
  }
}

/// SQLite qua sqflite: 1 bảng kv cho snapshot + op queue (giá trị JSON).
class SqliteLocalDb implements LocalDb {
  static const _dbName = 'smartcafe.db';
  static const _table = 'kv';
  sqflite.Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dir = await sqflite.databaseFactory.getDatabasesPath();
    _db = await sqflite.databaseFactory.openDatabase(
      '$dir/$_dbName',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE $_table (k TEXT PRIMARY KEY, v TEXT NOT NULL)');
      },
    );
  }

  @override
  Future<String?> read(String key) async {
    final rows =
        await _db?.query(_table, where: 'k = ?', whereArgs: [key], limit: 1);
    if (rows == null || rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    await _db?.insert(_table, {'k': key, 'v': value},
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String key) async {
    await _db?.delete(_table, where: 'k = ?', whereArgs: [key]);
  }
}
