import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/reminders/data/reminder_repository.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'Fresh schema includes reminders and preserves all data across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ngenbills-schema-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/test.db';
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(database.close);
      final debts = DebtRepository(database);
      await debts.create(name: 'บัตรเครดิต', amountMinor: 1000000);
      final debtId = (await debts.load())!.debt.id;
      await PaymentRepository(database)
          .add(debtId: debtId, amountMinor: 300000, date: DateTime(2026, 1, 1));
      final summary = (await debts.load())!;
      expect(summary.debt.id, debtId);
      expect(summary.payments.single.amountMinor, 300000);
      expect(summary.remaining, 700000);
      final reminders = ReminderRepository(database);
      expect(await reminders.load(debtId), isNull);
      expect(await reminders.onboardingDone(), false);
      expect(await (await database.instance).getVersion(), 2);
      await reminders.completeOnboarding();
      await reminders.save(
        ReminderSettings(
          debtId: debtId,
          dueDay: 31,
          advanceDays: {7},
          hour: 23,
          minute: 59,
          enabled: true,
          remindOnDueDate: false,
        ),
      );
      await database.close();
      final loaded = (await reminders.load(debtId))!;
      expect(loaded.dueDay, 31);
      expect(loaded.hour, 23);
      expect(loaded.minute, 59);
      expect(loaded.enabled, true);
      expect(loaded.remindOnDueDate, false);
      expect(await reminders.onboardingDone(), true);
      final reopened = (await DebtRepository(database).load())!;
      expect(reopened.remaining, 700000);
      expect(reopened.payments.single.id, summary.payments.single.id);
    },
  );

  for (final lead in [0, 1, 3, 7]) {
    test('v1 migration preserves data for lead $lead', () async {
      final directory = await Directory.systemTemp.createTemp('ngenbills-v1-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/old.db';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1),
      );
      await old.execute(
        "CREATE TABLE debts (id TEXT PRIMARY KEY, name TEXT, initial_amount_minor INTEGER, note TEXT, created_at TEXT, updated_at TEXT)",
      );
      await old.execute(
        "CREATE TABLE payments (id TEXT PRIMARY KEY, debt_id TEXT REFERENCES debts(id) ON DELETE CASCADE, amount_minor INTEGER, payment_date TEXT, note TEXT, created_at TEXT)",
      );
      await old.execute(
        "CREATE TABLE app_preferences (key TEXT PRIMARY KEY, value TEXT)",
      );
      await old.execute(
        "CREATE TABLE reminder_settings (debt_id TEXT PRIMARY KEY REFERENCES debts(id) ON DELETE CASCADE, due_day INTEGER, days_before INTEGER, hour INTEGER, minute INTEGER, enabled INTEGER, remind_on_due_date INTEGER)",
      );
      await old.insert('debts', {
        'id': 'debt',
        'name': 'เดิม',
        'initial_amount_minor': 100000,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      await old.insert('payments', {
        'id': 'payment',
        'debt_id': 'debt',
        'amount_minor': 20000,
        'payment_date': '2026-01-02T00:00:00Z',
        'created_at': '2026-01-02T00:00:00Z',
      });
      await old.insert('app_preferences', {
        'key': 'notification_onboarding_done',
        'value': '1',
      });
      await old.insert('reminder_settings', {
        'debt_id': 'debt',
        'due_day': 31,
        'days_before': lead,
        'hour': 14,
        'minute': 37,
        'enabled': 1,
        'remind_on_due_date': 0,
      });
      final debtRows = await old.query('debts');
      final paymentRows = await old.query('payments');
      await old.close();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(database.close);
      final repository = ReminderRepository(database);
      final settings = (await repository.load('debt'))!;
      expect(settings.advanceDays, lead == 0 ? <int>{} : {lead});
      expect(settings.dueDay, 31);
      expect(settings.hour, 14);
      expect(settings.minute, 37);
      expect(settings.enabled, true);
      expect(settings.remindOnDueDate, false);
      expect(await repository.onboardingDone(), true);
      expect(await (await database.instance).query('debts'), debtRows);
      expect(await (await database.instance).query('payments'), paymentRows);
      await repository.save(
        ReminderSettings(debtId: 'debt', dueDay: 31, advanceDays: {1, 3, 7}),
      );
      await database.close();
      expect((await repository.load('debt'))!.advanceDays, {1, 3, 7});
      await (await database.instance).delete('debts');
      expect(await repository.load('debt'), isNull);
    });
  }

  test(
    'Fresh schema settings validate and foreign key prevents orphan reminders',
    () async {
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final repository = ReminderRepository(database);
      await expectLater(
        repository.save(const ReminderSettings(debtId: 'missing', dueDay: 10)),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        repository.save(const ReminderSettings(debtId: 'missing', dueDay: 0)),
        throwsArgumentError,
      );
      await expectLater(
        repository.save(
          const ReminderSettings(
            debtId: 'missing',
            dueDay: 10,
            advanceDays: {2},
          ),
        ),
        throwsArgumentError,
      );
    },
  );
}
