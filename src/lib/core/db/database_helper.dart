import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<Database> openAppDatabase() async {
  final dbPath = await getDatabasesPath();
  final fullPath = p.join(dbPath, 'time_tracker.db');
  return openDatabase(
    fullPath,
    version: 2,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );
}

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE categories ADD COLUMN isHidden INTEGER NOT NULL DEFAULT 0',
    );
  }
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE categories (
      id       INTEGER PRIMARY KEY AUTOINCREMENT,
      name     TEXT    NOT NULL,
      colorHex TEXT    NOT NULL,
      isPreset INTEGER NOT NULL DEFAULT 0,
      isHidden INTEGER NOT NULL DEFAULT 0
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

/// Must be overridden with the result of [openAppDatabase] in main.dart,
/// and with an in-memory database in tests.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);
