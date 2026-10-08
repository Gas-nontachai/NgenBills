import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/core/errors/app_exception.dart';
import 'package:ngenbills/core/formatters/currency_formatter.dart';
import 'package:ngenbills/core/formatters/date_formatter.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/data/repositories/borrowing_repository.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/reminders/data/reminder_repository.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase db;
  late DebtRepository debts;
  late BorrowingRepository borrowings;
  late PaymentRepository payments;
  late String id;
  setUp(() async {
    db = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    debts = DebtRepository(db);
    borrowings = BorrowingRepository(db);
    payments = PaymentRepository(db);
    await debts.create(
      name: 'เดิม',
      amountMinor: 13000000,
      note: 'เก็บหมายเหตุเดิม',
    );
    id = (await debts.load())!.debt.id;
  });
  tearDown(() => db.close());

  test(
    'Borrowing preserves principal and uses total debt for payment checks',
    () async {
      final receipt = await borrowings.add(
        debtId: id,
        amountMinor: 500000,
        date: AppDates.today(),
        note: 'ซ่อมรถ',
      );
      expect(receipt.previousRemaining, 13000000);
      expect(receipt.remaining, 13500000);
      await payments.add(
        debtId: id,
        amountMinor: 2500000,
        date: AppDates.today(),
      );
      final summary = (await debts.load())!;
      expect(summary.debt.initialAmountMinor, 13000000);
      expect(summary.totalDebt, 13500000);
      expect(summary.remaining, 11000000);
      expect(summary.progressLabel, '18.5');
      expect(summary.borrowings.single.note, 'ซ่อมรถ');
      await payments.add(
        debtId: id,
        amountMinor: 11000000,
        date: AppDates.today(),
      );
      expect((await debts.load())!.isPaid, true);
      await expectLater(
        payments.add(debtId: id, amountMinor: 1, date: AppDates.today()),
        throwsA(isA<AppException>()),
      );
      await borrowings.add(debtId: id, amountMinor: 1, date: AppDates.today());
      expect((await debts.load())!.remaining, 1);
      expect((await debts.load())!.isPaid, false);
    },
  );

  test('Deleting borrowing allows zero balance but refuses negative balance atomically', () async {
    await borrowings.add(
      debtId: id,
      amountMinor: 500000,
      date: AppDates.today(),
    );
    final borrowing = (await debts.load())!.borrowings.single;
    await payments.add(
      debtId: id,
      amountMinor: 13000001,
      date: AppDates.today(),
    );
    await expectLater(
      borrowings.delete(borrowing.id),
      throwsA(isA<AppException>()),
    );
    expect((await debts.load())!.remaining, 499999);
    expect((await debts.load())!.borrowings.single.id, borrowing.id);
    await payments.delete((await debts.load())!.payments.single.id);
    await payments.add(
      debtId: id,
      amountMinor: 13000000,
      date: AppDates.today(),
    );
    expect(await borrowings.delete(borrowing.id), true);
    expect((await debts.load())!.isPaid, true);
    expect(await borrowings.delete(borrowing.id), false);
  });

  test(
    'Invalid borrowing input and aggregate overflow leave no writes',
    () async {
      for (final amount in [0, -1, Money.maxMinor + 1]) {
        await expectLater(
          borrowings.add(
            debtId: id,
            amountMinor: amount,
            date: AppDates.today(),
          ),
          throwsA(isA<AppException>()),
        );
      }
      await expectLater(
        borrowings.add(
          debtId: id,
          amountMinor: 1,
          date: AppDates.today().add(const Duration(days: 1)),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        borrowings.add(debtId: id, amountMinor: 1, date: DateTime(1899)),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        borrowings.add(
          debtId: 'missing',
          amountMinor: 1,
          date: AppDates.today(),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        borrowings.add(
          debtId: id,
          amountMinor: 1,
          date: AppDates.today(),
          note: 'x' * 501,
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        borrowings.add(
          debtId: id,
          amountMinor: Money.maxMinor,
          date: AppDates.today(),
        ),
        throwsA(isA<AppException>()),
      );
      expect((await debts.load())!.borrowings, isEmpty);
      await borrowings.add(
        debtId: id,
        amountMinor: Money.maxMinor - 13000000,
        date: AppDates.today(),
      );
      await expectLater(
        borrowings.add(debtId: id, amountMinor: 1, date: AppDates.today()),
        throwsA(isA<AppException>()),
      );
      expect((await debts.load())!.totalDebt, Money.maxMinor);
    },
  );

  test(
    'Concurrent borrowing totals and payment/deletion remain consistent',
    () async {
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          borrowings
              .add(
                debtId: id,
                amountMinor: Money.maxMinor - 13000000,
                date: AppDates.today(),
              )
              .then((_) => true)
              .catchError((Object _) => false),
      ]);
      expect(results.where((r) => r), hasLength(1));
      final borrowing = (await debts.load())!.borrowings.single;
      final competing = await Future.wait([
        payments
            .add(debtId: id, amountMinor: 13000001, date: AppDates.today())
            .then((_) => true)
            .catchError((Object _) => false),
        borrowings.delete(borrowing.id).catchError((Object _) => false),
      ]);
      expect(competing.where((r) => r), hasLength(1));
      expect((await debts.load())!.remaining, greaterThanOrEqualTo(0));
    },
  );

  test(
    'Customize validates keys and retains principal, notes and history',
    () async {
      await payments.add(debtId: id, amountMinor: 1, date: AppDates.today());
      await debts.customize(
        debtId: id,
        name: '  ใหม่  ',
        iconKey: 'car',
        colorKey: 'pink',
      );
      final summary = (await debts.load())!;
      expect(summary.debt.name, 'ใหม่');
      expect(summary.debt.iconKey, 'car');
      expect(summary.debt.colorKey, 'pink');
      expect(summary.debt.note, 'เก็บหมายเหตุเดิม');
      expect(summary.debt.initialAmountMinor, 13000000);
      expect(summary.totalPaid, 1);
      for (final name in ['', 'x' * 101]) {
        await expectLater(
          debts.customize(
            debtId: id,
            name: name,
            iconKey: 'wallet',
            colorKey: 'green',
          ),
          throwsA(isA<AppException>()),
        );
      }
      await expectLater(
        debts.customize(
          debtId: id,
          name: 'ใหม่',
          iconKey: 'invalid',
          colorKey: 'green',
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        debts.customize(
          debtId: 'missing',
          name: 'ใหม่',
          iconKey: 'wallet',
          colorKey: 'green',
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'Account deletion cascades but preserves completed onboarding',
    () async {
      await payments.add(debtId: id, amountMinor: 1, date: AppDates.today());
      await borrowings.add(debtId: id, amountMinor: 1, date: AppDates.today());
      final reminders = ReminderRepository(db);
      await reminders.completeOnboarding();
      await reminders.save(ReminderSettings(debtId: id, dueDay: 10));
      expect(await debts.delete(id), true);
      expect(await debts.load(), isNull);
      for (final table in ['payments', 'borrowings', 'reminder_settings']) {
        expect(await (await db.instance).query(table), isEmpty);
      }
      expect(await reminders.onboardingDone(), true);
      expect(await debts.delete(id), false);
      await debts.create(name: 'ใหม่', amountMinor: 100);
      expect((await debts.load())!.debt.iconKey, 'wallet');
      expect((await debts.load())!.debt.colorKey, 'green');
      await expectLater(
        borrowings.add(debtId: id, amountMinor: 1, date: AppDates.today()),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('Version 1 account and history persist across reopen', () async {
    final temp = await Directory.systemTemp.createTemp('ngenbills-v1-');
    addTearDown(() => temp.delete(recursive: true));
    final persistent = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temp.path}/test.db',
    );
    addTearDown(persistent.close);
    final repo = DebtRepository(persistent);
    await repo.create(
      name: 'Account',
      amountMinor: 10000,
      note: 'Original note',
    );
    final debtId = (await repo.load())!.debt.id;
    await PaymentRepository(persistent)
        .add(debtId: debtId, amountMinor: 1, date: DateTime(2026, 1, 2));
    await ReminderRepository(persistent).completeOnboarding();
    var summary = (await repo.load())!;
    final paymentId = summary.payments.single.id;
    expect(await (await persistent.instance).getVersion(), 1);
    expect(summary.debt.iconKey, 'wallet');
    expect(summary.debt.colorKey, 'green');
    expect(summary.remaining, 9999);
    await repo.customize(
      debtId: debtId,
      name: 'Renamed',
      iconKey: 'travel',
      colorKey: 'purple',
    );
    await BorrowingRepository(persistent).add(
      debtId: debtId,
      amountMinor: 101,
      date: DateTime(2026, 1, 3),
      note: 'Borrowing note',
    );
    await persistent.close();
    summary = (await repo.load())!;
    expect(summary.debt.name, 'Renamed');
    expect(summary.debt.iconKey, 'travel');
    expect(summary.debt.colorKey, 'purple');
    expect(summary.debt.note, 'Original note');
    expect(summary.remaining, 10100);
    expect(summary.payments.single.id, paymentId);
    expect(summary.borrowings.single.note, 'Borrowing note');
    expect(summary.borrowings.single.createdAt.isUtc, true);
    expect(await ReminderRepository(persistent).onboardingDone(), true);
    expect(await (await persistent.instance).getVersion(), 1);
  });
}
