import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _path = databasePath;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;
  Future<void>? _closing;
  Future<Database> get instance => _opening ??= _open();
  Future<Database> _open() async {
    try {
      await _closing;
      final location =
          _path ?? path.join(await _factory.getDatabasesPath(), 'ngenbills.db');
      return await _factory.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) => createSchema(db),
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() {
    final pending = _opening;
    if (pending == null) return _closing ?? Future.value();
    _opening = null;
    final closing = pending.then((db) => db.close());
    _closing = closing;
    return closing.whenComplete(() {
      if (identical(_closing, closing)) _closing = null;
    });
  }
}
