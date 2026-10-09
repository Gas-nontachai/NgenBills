import 'dart:convert';
import 'dart:typed_data';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/formatters/currency_formatter.dart';
import '../../debt/domain/entities/account_appearance.dart';

/// A validated, immutable backup. Only the decoder can construct one.
class BackupSnapshot {
  const BackupSnapshot._(this.createdAt, this.tables);

  final DateTime createdAt;
  final Map<String, List<Map<String, Object?>>> tables;
  int get accountCount => tables['debts']!.length;
  int get paymentCount => tables['payments']!.length;
  int get borrowingCount => tables['borrowings']!.length;
}

class BackupService {
  BackupService(this.database);
  final AppDatabase database;

  static const formatVersion = 1;
  static const schemaVersion = 1;
  static const maxFileBytes = 32 * 1024 * 1024;
  static const _columns = {
    'debts': {
      'id',
      'name',
      'initial_amount_minor',
      'icon_key',
      'color_key',
      'note',
      'created_at',
      'updated_at',
    },
    'payments': {
      'id',
      'debt_id',
      'amount_minor',
      'payment_date',
      'note',
      'created_at',
    },
    'borrowings': {
      'id',
      'debt_id',
      'amount_minor',
      'borrowing_date',
      'note',
      'created_at',
    },
    'reminder_settings': {
      'debt_id',
      'due_day',
      'advance_days_mask',
      'hour',
      'minute',
      'enabled',
      'remind_on_due_date',
    },
    'app_preferences': {'key', 'value'},
  };

  Future<Uint8List> export() async {
    final db = await database.instance;
    final document = await db.transaction((txn) async {
      final version = await txn.rawQuery('PRAGMA user_version');
      if (version.single.values.single != schemaVersion) {
        throw const AppException('เวอร์ชันฐานข้อมูลนี้ยังไม่รองรับการสำรอง');
      }
      final tables = <String, Object?>{};
      for (final table in _columns.keys) {
        tables[table] = await txn.query(table);
      }
      return {
        'app': 'ngenbills',
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'data': tables,
      };
    });
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(document)));
    if (bytes.length > maxFileBytes) {
      throw const AppException('ข้อมูลมีขนาดเกิน 32 MB ที่รองรับ');
    }
    // Do not produce a backup that this version cannot restore.
    decode(bytes);
    return bytes;
  }

  BackupSnapshot decode(Uint8List bytes) {
    if (bytes.length > maxFileBytes) {
      throw const AppException('ไฟล์สำรองมีขนาดเกิน 32 MB ที่รองรับ');
    }
    try {
      final document = _map(jsonDecode(utf8.decode(bytes)));
      _check(document['app'] == 'ngenbills');
      if (document['formatVersion'] is! int ||
          document['schemaVersion'] is! int ||
          document['formatVersion'] != formatVersion ||
          document['schemaVersion'] != schemaVersion) {
        throw const AppException(
          'ไม่รองรับเวอร์ชันไฟล์สำรองนี้ กรุณาใช้แอปเวอร์ชันที่ตรงกัน',
        );
      }
      final createdAt = _timestamp(document['createdAt']);
      final data = _map(document['data']);
      _check(_sameKeys(data.keys, _columns.keys));
      final tables = <String, List<Map<String, Object?>>>{};
      for (final entry in _columns.entries) {
        final raw = data[entry.key];
        _check(raw is List);
        final ids = <String>{};
        final rows = <Map<String, Object?>>[];
        for (final value in raw as List) {
          final row = _map(value);
          _check(_sameKeys(row.keys, entry.value));
          final idKey = entry.key == 'app_preferences'
              ? 'key'
              : entry.key == 'reminder_settings'
              ? 'debt_id'
              : 'id';
          _check(ids.add(_string(row[idKey])));
          _validateRow(entry.key, row);
          rows.add(Map.unmodifiable(row));
        }
        tables[entry.key] = List.unmodifiable(rows);
      }
      _validateRelations(tables);
      return BackupSnapshot._(createdAt, Map.unmodifiable(tables));
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'ไฟล์สำรองไม่ถูกต้องหรือเสียหาย ข้อมูลเดิมยังไม่ถูกเปลี่ยน',
      );
    }
  }

  /// The caller serializes this with app writes and reminder reconciliation.
  Future<void> restore(BackupSnapshot snapshot) async {
    final db = await database.instance;
    await db.transaction((txn) async {
      final version = await txn.rawQuery('PRAGMA user_version');
      if (version.single.values.single != schemaVersion) {
        throw const AppException('เวอร์ชันฐานข้อมูลนี้ยังไม่รองรับการกู้คืน');
      }
      // Children first on delete; parents first on insert. Keep foreign keys on.
      for (final table in [
        'reminder_settings',
        'payments',
        'borrowings',
        'app_preferences',
        'debts',
      ]) {
        await txn.delete(table);
      }
      for (final table in _columns.keys) {
        for (final row in snapshot.tables[table]!) {
          await txn.insert(table, row);
        }
      }
      final violations = await txn.rawQuery('PRAGMA foreign_key_check');
      _check(violations.isEmpty);
    });
  }

  static void _validateRow(String table, Map<String, Object?> row) {
    if (table == 'app_preferences') {
      _check(row['value'] is String);
      if (row['key'] == 'notification_onboarding_done') {
        _check(row['value'] == '0' || row['value'] == '1');
      }
      return;
    }
    if (table == 'reminder_settings') {
      _integer(row['due_day'], 1, 31);
      _integer(row['advance_days_mask'], 0, 7);
      _integer(row['hour'], 0, 23);
      _integer(row['minute'], 0, 59);
      _integer(row['enabled'], 0, 1);
      _integer(row['remind_on_due_date'], 0, 1);
      return;
    }
    _timestamp(row['created_at']);
    _check(
      row['note'] == null ||
          (row['note'] is String && (row['note'] as String).length <= 500),
    );
    if (table == 'debts') {
      final name = _string(row['name']);
      _check(name.trim().isNotEmpty && name.trim().length <= 100);
      _integer(row['initial_amount_minor'], 1, Money.maxMinor);
      _check(AccountAppearance.iconKeys.contains(row['icon_key']));
      _check(AccountAppearance.colorKeys.contains(row['color_key']));
      _timestamp(row['updated_at']);
    } else {
      _string(row['debt_id']);
      _integer(row['amount_minor'], 1, Money.maxMinor);
      _date(row[table == 'payments' ? 'payment_date' : 'borrowing_date']);
    }
  }

  static void _validateRelations(
    Map<String, List<Map<String, Object?>>> tables,
  ) {
    final totals = <String, int>{
      for (final row in tables['debts']!)
        row['id'] as String: row['initial_amount_minor'] as int,
    };
    final paid = <String, int>{};
    for (final table in ['borrowings', 'payments', 'reminder_settings']) {
      for (final row in tables[table]!) {
        final id = _string(row['debt_id']);
        _check(totals.containsKey(id));
        if (table == 'borrowings') {
          totals[id] = totals[id]! + (row['amount_minor'] as int);
          _check(totals[id]! <= Money.maxMinor);
        } else if (table == 'payments') {
          paid[id] = (paid[id] ?? 0) + (row['amount_minor'] as int);
          _check(paid[id]! <= totals[id]!);
        }
      }
    }
    for (final row in tables['app_preferences']!) {
      if (row['key'] == 'default_debt_id') {
        _check(totals.containsKey(row['value']));
      }
    }
  }

  static Map<String, Object?> _map(Object? value) {
    _check(value is Map<String, dynamic>);
    return Map<String, Object?>.from(value as Map);
  }

  static bool _sameKeys(Iterable<String> actual, Iterable<String> expected) =>
      actual.length == expected.length && actual.toSet().containsAll(expected);

  static String _string(Object? value) {
    _check(value is String && value.isNotEmpty);
    return value as String;
  }

  static void _integer(Object? value, int min, int max) =>
      _check(value is int && value >= min && value <= max);

  static DateTime _timestamp(Object? value) {
    final text = _string(value);
    _check(
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$')
          .hasMatch(text),
    );
    final parsed = DateTime.parse(text);
    // DateTime.parse normalizes impossible dates/times; reject those explicitly.
    _check(parsed.toIso8601String().substring(0, 19) == text.substring(0, 19));
    return parsed;
  }

  static void _date(Object? value) {
    final text = _string(value);
    _check(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text));
    final parsed = DateTime.parse(text);
    _check(
      parsed.year >= 1900 && parsed.toIso8601String().substring(0, 10) == text,
    );
  }

  static void _check(bool valid) {
    if (!valid) {
      throw const AppException(
        'ไฟล์สำรองไม่ถูกต้องหรือเสียหาย ข้อมูลเดิมยังไม่ถูกเปลี่ยน',
      );
    }
  }
}
