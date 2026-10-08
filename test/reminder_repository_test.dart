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
      expect(await (await database.instance).getVersion(), 1);
      await reminders.completeOnboarding();
      await reminders.save(
        ReminderSettings(
          debtId: debtId,
          dueDay: 31,
          daysBefore: 7,
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
          const ReminderSettings(debtId: 'missing', dueDay: 10, daysBefore: 2),
        ),
        throwsArgumentError,
      );
    },
  );
}
