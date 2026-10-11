import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/core/errors/app_exception.dart';
import 'package:ngenbills/core/formatters/currency_formatter.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/data/repositories/borrowing_repository.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory temp;
  late AppDatabase database;
  late DebtRepository debts;
  late PaymentRepository payments;
  late BorrowingRepository borrowings;
  final date = DateTime(2020, 1, 1);
  late String debtId, paymentId, borrowingId;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('edit-history-');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temp.path}/test.db',
    );
    debts = DebtRepository(database);
    payments = PaymentRepository(database);
    borrowings = BorrowingRepository(database);
    debtId = await debts.create(name: 'Test', amountMinor: 10000);
    await borrowings.add(
      debtId: debtId,
      amountMinor: 5000,
      date: date,
      note: 'old',
    );
    await payments.add(
      debtId: debtId,
      amountMinor: 12000,
      date: date,
      note: 'old',
    );
    final summary = (await debts.load(debtId))!;
    paymentId = summary.payments.single.id;
    borrowingId = summary.borrowings.single.id;
  });
  tearDown(() async {
    await database.close();
    await temp.delete(recursive: true);
  });

  test('Edits retain identity and sticky markers after reopen', () async {
    final before = (await debts.load(debtId))!;
    await payments.update(
      id: paymentId,
      amountMinor: 11000,
      date: DateTime(2020, 2, 1),
      note: '',
    );
    await borrowings.update(
      id: borrowingId,
      amountMinor: 6000,
      date: DateTime(2020, 3, 1),
      note: ' new ',
    );
    await database.close();
    final summary = (await debts.load(debtId))!;
    expect(summary.payments.single.id, paymentId);
    expect(summary.payments.single.createdAt, before.payments.single.createdAt);
    expect(summary.payments.single.isEdited, true);
    expect(summary.payments.single.note, '');
    expect(summary.payments.single.date, DateTime(2020, 2, 1));
    expect(
      summary.borrowings.single.createdAt,
      before.borrowings.single.createdAt,
    );
    expect(summary.borrowings.single.isEdited, true);
    expect(summary.borrowings.single.note, 'new');
    expect(summary.history.first.id, borrowingId);
    expect(summary.remaining, 5000);
    await payments.update(
      id: paymentId,
      amountMinor: 12000,
      date: date,
      note: 'old',
    );
    await borrowings.update(
      id: borrowingId,
      amountMinor: 5000,
      date: date,
      note: 'old',
    );
    expect((await debts.load(debtId))!.payments.single.isEdited, true);
    expect((await debts.load(debtId))!.borrowings.single.isEdited, true);
  });

  test('Unchanged normalized fields leave rows untouched', () async {
    final db = await database.instance;
    final before = await db.query('debts');
    await payments.update(
      id: paymentId,
      amountMinor: 12000,
      date: date,
      note: ' old ',
    );
    await borrowings.update(
      id: borrowingId,
      amountMinor: 5000,
      date: date,
      note: ' old ',
    );
    expect(await db.query('debts'), before);
    expect((await debts.load(debtId))!.payments.single.isEdited, false);
    expect((await debts.load(debtId))!.borrowings.single.isEdited, false);
  });

  test(
    'Replacement bounds allow exactly paid and reject negative remaining',
    () async {
      await expectLater(
        payments.update(id: paymentId, amountMinor: 15001, date: date),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        borrowings.update(id: borrowingId, amountMinor: 1999, date: date),
        throwsA(isA<AppException>()),
      );
      expect((await debts.load(debtId))!.payments.single.isEdited, false);
      expect((await debts.load(debtId))!.borrowings.single.isEdited, false);
      await borrowings.update(id: borrowingId, amountMinor: 2000, date: date);
      expect((await debts.load(debtId))!.isPaid, true);
      await payments.update(id: paymentId, amountMinor: 11000, date: date);
      expect((await debts.load(debtId))!.remaining, 1000);
      await payments.update(id: paymentId, amountMinor: 12000, date: date);
      expect((await debts.load(debtId))!.isPaid, true);
    },
  );

  test('Invalid edits and missing rows never partially write', () async {
    final db = await database.instance;
    for (final table in ['payments', 'borrowings']) {
      final before = await db.query(table);
      final update = table == 'payments' ? payments.update : borrowings.update;
      final id = table == 'payments' ? paymentId : borrowingId;
      for (final amount in [0, -1, Money.maxMinor + 1]) {
        await expectLater(
          update(id: id, amountMinor: amount, date: date),
          throwsA(isA<AppException>()),
        );
      }
      for (final invalidDate in [
        DateTime(1899),
        DateTime.now().add(const Duration(days: 2)),
      ]) {
        await expectLater(
          update(id: id, amountMinor: 100, date: invalidDate),
          throwsA(isA<AppException>()),
        );
      }
      await expectLater(
        update(id: id, amountMinor: 100, date: date, note: 'x' * 501),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        update(id: 'missing', amountMinor: 100, date: date),
        throwsA(isA<AppException>()),
      );
      expect(await db.query(table), before);
    }
    await expectLater(
      borrowings.update(
        id: borrowingId,
        amountMinor: Money.maxMinor,
        date: date,
      ),
      throwsA(isA<AppException>()),
    );
    await borrowings.update(
      id: borrowingId,
      amountMinor: Money.maxMinor - 10000,
      date: date,
    );
    expect((await debts.load(debtId))!.totalDebt, Money.maxMinor);
  });

  test('SQL failure rolls back edit and marker', () async {
    final db = await database.instance;
    await db.execute(
      "CREATE TRIGGER fail_edit BEFORE UPDATE ON debts BEGIN SELECT RAISE(ABORT, 'forced'); END",
    );
    await expectLater(
      payments.update(id: paymentId, amountMinor: 11000, date: date),
      throwsA(isA<DatabaseException>()),
    );
    expect((await debts.load(debtId))!.payments.single.amountMinor, 12000);
    expect((await debts.load(debtId))!.payments.single.isEdited, false);
  });

  test('Initial schema remains version 1 with unedited defaults', () async {
    final summary = (await debts.load(debtId))!;
    expect(summary.payments.single.isEdited, false);
    expect(summary.borrowings.single.isEdited, false);
    final db = await database.instance;
    expect(await db.getVersion(), 1);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
