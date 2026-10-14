import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/data/repositories/borrowing_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/reminders/data/reminder_repository.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';

import 'support/schema_v1.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'Both directions persist and keep the same transaction behavior',
    () async {
      final temp = await Directory.systemTemp.createTemp('direction-');
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temp.path}/test.db',
      );
      addTearDown(() async {
        await database.close();
        await temp.delete(recursive: true);
      });
      final repo = DebtRepository(database);
      final defaultId = await repo.create(name: 'default', amountMinor: 1000);
      expect(
        (await repo.load(defaultId))!.debt.direction,
        DebtDirection.payable,
      );
      for (final direction in DebtDirection.values) {
        final id = await repo.create(
          name: direction.name,
          amountMinor: 1000,
          direction: direction,
        );
        await BorrowingRepository(database)
            .add(debtId: id, amountMinor: 200, date: DateTime(2026, 1, 1));
        await PaymentRepository(database)
            .add(debtId: id, amountMinor: 300, date: DateTime(2026, 1, 1));
        await repo.customize(
          debtId: id,
          name: 'renamed',
          iconKey: 'car',
          colorKey: 'pink',
        );
        await database.close();
        final summary = (await repo.load(id))!;
        expect(summary.debt.direction, direction);
        expect(summary.remaining, 900);
        expect(summary.totalPaid, 300);
        expect(summary.borrowings, hasLength(1));
        expect(summary.payments, hasLength(1));
        expect(
          (await repo.list()).singleWhere((d) => d.id == id).direction,
          direction,
        );
        expect(
          (await repo.loadAll())
              .singleWhere((s) => s.debt.id == id)
              .debt
              .direction,
          direction,
        );
      }
      final sql = await database.instance;
      for (final invalid in [null, 'invalid']) {
        await expectLater(
          sql.update(
            'debts',
            {'direction': invalid},
            where: 'id = ?',
            whereArgs: [defaultId],
          ),
          throwsA(isA<DatabaseException>()),
        );
      }
    },
  );

  test(
    'Real version 1 upgrade preserves all existing rows and relations',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'direction-migration-',
      );
      final location = '${temp.path}/test.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        location,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => createLegacySchema(db),
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        ),
      );
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: location,
      );
      addTearDown(() async {
        await database.close();
        if (legacy.isOpen) await legacy.close();
        await temp.delete(recursive: true);
      });
      const stamp = '2026-01-01T00:00:00.000Z';
      for (final id in ['a', 'b']) {
        await legacy.insert('debts', {
          'id': id,
          'name': id,
          'initial_amount_minor': 1000,
          'note': 'original',
          'created_at': stamp,
          'updated_at': stamp,
        });
      }
      for (final table in ['payments', 'borrowings']) {
        await legacy.insert(table, {
          'id': table,
          'debt_id': 'a',
          'amount_minor': 100,
          table == 'payments' ? 'payment_date' : 'borrowing_date': '2026-01-01',
          'note': 'history',
          'created_at': stamp,
          'is_edited': 1,
        });
      }
      await legacy.insert(
        'reminder_settings',
        ReminderSettings(debtId: 'a', dueDay: 10).toMap(),
      );
      await legacy.insert('app_preferences', {
        'key': 'default_debt_id',
        'value': 'b',
      });
      await legacy.insert('app_preferences', {
        'key': 'account_order',
        'value': '["b","a"]',
      });
      final before = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'debts',
        'payments',
        'borrowings',
        'reminder_settings',
        'app_preferences',
      ]) {
        before[table] = await legacy.query(
          table,
          orderBy: table == 'app_preferences'
              ? 'key'
              : table == 'reminder_settings'
              ? 'debt_id'
              : 'id',
        );
      }
      await legacy.close();
      final upgraded = await database.instance;
      expect(await upgraded.getVersion(), 2);
      for (final entry in before.entries) {
        final after = await upgraded.query(
          entry.key,
          orderBy: entry.key == 'app_preferences'
              ? 'key'
              : entry.key == 'reminder_settings'
              ? 'debt_id'
              : 'id',
        );
        if (entry.key == 'debts') {
          for (final row in after) {
            expect(row['direction'], 'payable');
          }
          expect(
            after
                .map(
                  (row) => Map<String, Object?>.from(row)..remove('direction'),
                )
                .toList(),
            entry.value,
          );
        } else {
          expect(after, entry.value);
        }
      }
      expect(await upgraded.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect((await DebtRepository(database).list()).map((d) => d.id), [
        'b',
        'a',
      ]);
      expect(await ReminderRepository(database).load('a'), isNotNull);
      await database.close();
      expect((await DebtRepository(database).load('a'))!.remaining, 1000);
      expect(await (await database.instance).getVersion(), 2);
    },
  );
}
