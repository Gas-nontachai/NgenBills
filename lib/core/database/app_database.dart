import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'migrations/schema_v1.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _path = databasePath;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;
  Future<Database> get instance => _opening ??= _open();
  Future<Database> _open() async {
    try {
      final location =
          _path ?? path.join(await _factory.getDatabasesPath(), 'ngenbills.db');
      return await _factory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => createSchemaV1(db),
          onUpgrade: (db, oldVersion, newVersion) async {
            // Add ordered, non-destructive version migrations here.
          },
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final pending = _opening;
    _opening = null;
    if (pending != null) await (await pending).close();
  }
}
