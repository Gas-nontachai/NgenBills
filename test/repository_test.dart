import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/core/errors/app_exception.dart';
import 'package:ngenbills/core/formatters/date_formatter.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase database;
  late DebtRepository debts;
  late PaymentRepository payments;
  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    debts = DebtRepository(database);
    payments = PaymentRepository(database);
  });
  tearDown(() => database.close());
  Future<String> seed() async {
    await debts.create(name: '  บัตรเครดิต  ', amountMinor: 1000000);
    return (await debts.load())!.debt.id;
  }

  test('Empty database and debt insertion with trimmed name', () async {
    expect(await debts.load(), isNull);
    final id = await seed();
    expect(id, matches(RegExp(r'^[a-f0-9-]{36}$')));
    expect((await debts.load())!.debt.name, 'บัตรเครดิต');
  });
  test('Duplicate debt rejected, including concurrent creation', () async {
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        debts
            .create(name: 'หนี้', amountMinor: 10000)
            .then((_) => true)
            .catchError((Object _) => false),
    ]);
    expect(results.where((r) => r).length, 1);
    expect((await (await database.instance).query('debts')).length, 1);
  });
  test('Invalid debt inputs rejected', () async {
    await expectLater(
      debts.create(name: ' ', amountMinor: 100),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      debts.create(name: 'หนี้', amountMinor: 0),
      throwsA(isA<AppException>()),
    );
    await expectLater(
      debts.create(name: 'หนี้', amountMinor: -1),
      throwsA(isA<AppException>()),
    );
  });
  test('Insert, ordering by date, deletion and missing deletion', () async {
    final id = await seed();
    await payments.add(
      debtId: id,
      amountMinor: 300000,
      date: DateTime(2026, 1, 1),
      note: 'โอน',
    );
    await payments.add(
      debtId: id,
      amountMinor: 150000,
      date: DateTime(2026, 1, 2),
    );
    var summary = (await debts.load())!;
    expect(summary.totalPaid, 450000);
    expect(summary.payments.first.amountMinor, 150000);
    expect(summary.payments.last.note, 'โอน');
    expect(await payments.delete(summary.payments.first.id), true);
    summary = (await debts.load())!;
    expect(summary.remaining, 700000);
    expect(summary.payments.length, 1);
    expect(await payments.delete('missing'), false);
  });
  test('Equal payment dates sort by creation time descending', () async {
    final id = await seed();
    await payments.add(debtId: id, amountMinor: 100, date: AppDates.today());
    await payments.add(debtId: id, amountMinor: 200, date: AppDates.today());
    // The clock may return equal timestamps for rapid writes. Set distinct
    // creation times explicitly to verify the secondary sort contract.
    final db = await database.instance;
    await db.update(
      'payments',
      {'created_at': '2026-01-01T01:00:00.000Z'},
      where: 'amount_minor = ?',
      whereArgs: [100],
    );
    await db.update(
      'payments',
      {'created_at': '2026-01-01T02:00:00.000Z'},
      where: 'amount_minor = ?',
      whereArgs: [200],
    );
    expect((await debts.load())!.payments.first.amountMinor, 200);
  });
  test(
    'Reject zero, negative, future, nonexistent debt and overpayment',
    () async {
      final id = await seed();
      for (final amount in [0, -100, 1000001]) {
        await expectLater(
          payments.add(debtId: id, amountMinor: amount, date: AppDates.today()),
          throwsA(isA<AppException>()),
        );
      }
      await expectLater(
        payments.add(
          debtId: id,
          amountMinor: 100,
          date: AppDates.today().add(const Duration(days: 1)),
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        payments.add(
          debtId: 'missing',
          amountMinor: 100,
          date: AppDates.today(),
        ),
        throwsA(isA<AppException>()),
      );
      expect((await debts.load())!.totalPaid, 0);
    },
  );
  test(
    'Concurrent writes validate against balance inside the transaction',
    () async {
      final id = await seed();
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          payments
              .add(debtId: id, amountMinor: 700000, date: AppDates.today())
              .then((_) => true)
              .catchError((Object _) => false),
      ]);
      expect(results.where((r) => r).length, 1);
      expect((await debts.load())!.remaining, 300000);
    },
  );
  test('Database constraints, foreign key enforcement and rollback', () async {
    final id = await seed();
    final db = await database.instance;
    expect((await db.rawQuery('PRAGMA foreign_keys')).first.values.first, 1);
    final row = {
      'id': 'bad',
      'debt_id': 'missing',
      'amount_minor': 100,
      'payment_date': '2026-01-01',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await expectLater(
      db.insert('payments', row),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('payments', {...row, 'debt_id': id, 'amount_minor': 0}),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.transaction((txn) async {
        await txn.insert('payments', {...row, 'debt_id': id});
        throw const AppException('rollback');
      }),
      throwsA(isA<AppException>()),
    );
    expect((await debts.load())!.payments, isEmpty);
  });
  test(
    'Debt, fractional payment and date persist after database reopen',
    () async {
      final temp = await Directory.systemTemp.createTemp('ngenbills_test_');
      final path = '${temp.path}/persistence.db';
      final first = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      try {
        final repo = DebtRepository(first);
        await repo.create(name: 'หนี้', amountMinor: 10001);
        final id = (await repo.load())!.debt.id;
        await PaymentRepository(first).add(
          debtId: id,
          amountMinor: 1,
          date: DateTime(2026, 1, 1),
          note: 'หนึ่งสตางค์',
        );
        await first.close();
        final reopened = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        try {
          final summary = (await DebtRepository(reopened).load())!;
          expect(summary.remaining, 10000);
          expect(summary.payments.single.note, 'หนึ่งสตางค์');
          expect(AppDates.storage(summary.payments.single.date), '2026-01-01');
          expect(summary.payments.single.createdAt.isUtc, true);
        } finally {
          await reopened.close();
        }
      } finally {
        await first.close();
        await temp.delete(recursive: true);
      }
    },
  );
}
