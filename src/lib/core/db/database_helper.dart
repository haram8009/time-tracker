import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'time_tracker.db');

    return openDatabase(
      fullPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        name     TEXT    NOT NULL,
        colorHex TEXT    NOT NULL,
        isPreset INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE time_blocks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL,
        startMinute INTEGER NOT NULL,
        endMinute   INTEGER NOT NULL,
        categoryId  INTEGER NOT NULL,
        note        TEXT,
        FOREIGN KEY(categoryId) REFERENCES categories(id)
      )
    ''');
  }

  /// Exposed for testing: injects an in-memory database.
  static void setDatabaseForTesting(Database db) {
    _db = db;
  }

  /// Exposed for testing: closes and clears the cached database.
  static Future<void> resetForTesting() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
