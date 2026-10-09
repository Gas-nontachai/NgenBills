import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/core/errors/app_exception.dart';
import 'package:ngenbills/features/backup/data/backup_service.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase database;
  late BackupService service;
  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    service = BackupService(database);
    final db = await database.instance;
    await db.insert('debts', {
      'id': 'original',
      'name': 'บัญชีหลัก',
      'initial_amount_minor': 10000,
      'icon_key': 'wallet',
      'color_key': 'green',
      'note': 'บันทึกภาษาไทย',
      'created_at': '2026-10-09T00:00:00.000Z',
      'updated_at': '2026-10-09T00:00:00.000Z',
    });
    for (final table in ['payments', 'borrowings']) {
      await db.insert(table, {
        'id': '$table-1',
        'debt_id': 'original',
        'amount_minor': 100,
        table == 'payments' ? 'payment_date' : 'borrowing_date': '2026-10-09',
        'note': 'ทดสอบ',
        'created_at': '2026-10-09T00:00:00.000Z',
      });
    }
    await db.insert('reminder_settings', {
      'debt_id': 'original',
      'due_day': 31,
      'advance_days_mask': 7,
      'hour': 14,
      'minute': 37,
      'enabled': 1,
      'remind_on_due_date': 1,
    });
    for (final entry in {
      'default_debt_id': 'original',
      'notification_onboarding_done': '1',
      'custom_preference': 'ค่าตั้งค่า',
    }.entries) {
      await db.insert('app_preferences', {
        'key': entry.key,
        'value': entry.value,
      });
    }
  });
  tearDown(() => database.close());
  Future<Map<String, dynamic>> document() async =>
      jsonDecode(utf8.decode(await service.export())) as Map<String, dynamic>;
  Uint8List encode(Map<String, dynamic> value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  test(
    'UTF-8 backup restores all five tables and replaces current configuration',
    () async {
      final original = await document();
      final snapshot = service.decode(encode(original));
      expect(snapshot.accountCount, 1);
      expect(snapshot.paymentCount, 1);
      expect(snapshot.borrowingCount, 1);
      final db = await database.instance;
      await db.update('debts', {'name': 'เปลี่ยนแล้ว', 'color_key': 'blue'});
      await db.delete('payments');
      await db.delete('app_preferences');
      await db.insert('app_preferences', {
        'key': 'extra',
        'value': 'remove me',
      });
      await service.restore(snapshot);
      expect((await document())['data'], original['data']);
      expect((await db.rawQuery('PRAGMA foreign_key_check')), isEmpty);
    },
  );

  test(
    'Empty account backup replaces data while preserving backed-up preferences',
    () async {
      final value = await document();
      final data = value['data'] as Map<String, dynamic>;
      for (final key in data.keys) {
        data[key] = <dynamic>[];
      }
      data['app_preferences'] = [
        {'key': 'notification_onboarding_done', 'value': '1'},
      ];
      await service.restore(service.decode(encode(value)));
      expect((await document())['data'], data);
    },
  );

  test('Insertion failure rolls back deletion and every table', () async {
    final before = await document();
    final snapshot = service.decode(encode(before));
    final db = await database.instance;
    await db.execute(
      "CREATE TRIGGER fail_import BEFORE INSERT ON payments BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
    );
    await expectLater(
      service.restore(snapshot),
      throwsA(isA<DatabaseException>()),
    );
    expect((await document())['data'], before['data']);
  });

  final invalid = <String, void Function(Map<String, dynamic>)>{
    'unsupported file version': (d) => d['formatVersion'] = 2,
    'unsupported schema': (d) => d['schemaVersion'] = 2,
    'wrong application': (d) => d['app'] = 'other',
    'missing table': (d) => (d['data'] as Map).remove('payments'),
    'duplicate ID': (d) =>
        (d['data']['debts'] as List).add(d['data']['debts'][0]),
    'orphan relationship': (d) =>
        d['data']['payments'][0]['debt_id'] = 'missing',
    'invalid default account': (d) =>
        d['data']['app_preferences'][0]['value'] = 'missing',
    'impossible date': (d) =>
        d['data']['payments'][0]['payment_date'] = '2026-02-30',
    'impossible timestamp': (d) => d['createdAt'] = '2026-02-30T00:00:00Z',
    'wrong amount type': (d) =>
        d['data']['payments'][0]['amount_minor'] = '100',
    'overpayment': (d) => d['data']['payments'][0]['amount_minor'] = 20000,
    'invalid reminder': (d) => d['data']['reminder_settings'][0]['enabled'] = 2,
  };
  for (final entry in invalid.entries) {
    test('Rejects ${entry.key} without changing existing data', () async {
      final before = await document();
      final changed = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      entry.value(changed);
      expect(
        () => service.decode(encode(changed)),
        throwsA(isA<AppException>()),
      );
      expect((await document())['data'], before['data']);
    });
  }
  test('Rejects malformed UTF-8 and JSON', () {
    for (final bytes in [
      Uint8List.fromList([255]),
      Uint8List.fromList(utf8.encode('{bad')),
    ]) {
      expect(() => service.decode(bytes), throwsA(isA<AppException>()));
    }
  });
  test('Validated snapshot is immutable', () async {
    final snapshot = service.decode(await service.export());
    expect(() => snapshot.tables.clear(), throwsUnsupportedError);
    expect(() => snapshot.tables['debts']!.clear(), throwsUnsupportedError);
    expect(
      () => snapshot.tables['debts']!.first['name'] = 'changed',
      throwsUnsupportedError,
    );
  });
}
