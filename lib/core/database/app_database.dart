import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase();

  Database? _database;
  Future<Database>? _opening;

  Future<Database> database() async {
    if (_database != null) {
      return _database!;
    }

    if (_opening != null) {
      return _opening!;
    }

    _opening = _open();
    _database = await _opening!;
    _opening = null;
    return _database!;
  }

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? orderBy,
    int? limit,
  }) async {
    final db = await database();
    return db.query(table, orderBy: orderBy, limit: limit);
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final db = await database();
    return db.insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<void> seedIfEmpty({
    required String table,
    required List<Map<String, Object?>> rows,
  }) async {
    final db = await database();
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM $table',
    );
    final count = countResult.first['count'] as int? ?? 0;
    if (count > 0) {
      return;
    }

    final batch = db.batch();
    for (final row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Database> _open() async {
    final factory = _databaseFactory();
    final dbPath = await _databasePath();

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.databaseVersion,
        onCreate: (db, version) async {
          for (final statement in DatabaseSchema.allCreateStatements) {
            await db.execute(statement);
          }
        },
      ),
    );
  }

  DatabaseFactory _databaseFactory() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }

    return databaseFactory;
  }

  Future<String> _databasePath() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationSupportDirectory();
      return p.join(directory.path, DatabaseSchema.databaseName);
    }

    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, DatabaseSchema.databaseName);
  }
}
