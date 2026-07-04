import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Current on-disk schema version. Bump + extend [migrateSchema] on changes.
const int appDatabaseVersion = 3;

Future<Database> openAppDatabase() async {
  final dbPath = await getDatabasesPath();
  final fullPath = p.join(dbPath, 'time_tracker.db');
  return openDatabase(
    fullPath,
    version: appDatabaseVersion,
    onCreate: (db, _) => createSchema(db),
    onUpgrade: migrateSchema,
  );
}

/// Creates the full current schema. Single source of truth shared by
/// [openAppDatabase]'s `onCreate` and tests.
Future<void> createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE categories (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      name       TEXT    NOT NULL,
      colorHex   TEXT    NOT NULL,
      isPreset   INTEGER NOT NULL DEFAULT 0,
      isHidden   INTEGER NOT NULL DEFAULT 0,
      remoteId   TEXT,
      ownerId    TEXT,
      updatedAt  TEXT    NOT NULL DEFAULT '',
      deletedAt  TEXT,
      syncStatus TEXT    NOT NULL DEFAULT 'pending'
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
      remoteId    TEXT,
      ownerId     TEXT,
      updatedAt   TEXT    NOT NULL DEFAULT '',
      deletedAt   TEXT,
      syncStatus  TEXT    NOT NULL DEFAULT 'pending',
      FOREIGN KEY(categoryId) REFERENCES categories(id)
    )
  ''');
}

/// Steps an older database up to [appDatabaseVersion]. Idempotent per step.
Future<void> migrateSchema(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE categories ADD COLUMN isHidden INTEGER NOT NULL DEFAULT 0',
    );
  }
  if (oldVersion < 3) {
    await _addSyncColumns(db, 'categories');
    await _addSyncColumns(db, 'time_blocks');
  }
}

/// Adds sync metadata columns to [table] and backfills existing rows so they
/// are pushed to the cloud on the next sync (pending, freshly timestamped).
Future<void> _addSyncColumns(Database db, String table) async {
  await db.execute('ALTER TABLE $table ADD COLUMN remoteId TEXT');
  await db.execute('ALTER TABLE $table ADD COLUMN ownerId TEXT');
  await db.execute(
    "ALTER TABLE $table ADD COLUMN updatedAt TEXT NOT NULL DEFAULT ''",
  );
  await db.execute('ALTER TABLE $table ADD COLUMN deletedAt TEXT');
  await db.execute(
    "ALTER TABLE $table ADD COLUMN syncStatus TEXT NOT NULL DEFAULT 'pending'",
  );

  await db.update(table, {
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
    'syncStatus': 'pending',
  });
}

/// Must be overridden with the result of [openAppDatabase] in main.dart,
/// and with an in-memory database in tests.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);
