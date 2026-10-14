import '../../domain/services/debt_wording.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';

class BorrowingReceipt {
  const BorrowingReceipt({
    required this.amountMinor,
    required this.previousRemaining,
  });
  final int amountMinor, previousRemaining;
  int get remaining => previousRemaining + amountMinor;
}

class BorrowingRepository {
  BorrowingRepository(this.database);
  final AppDatabase database;

  Future<BorrowingReceipt> add({
    required String debtId,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) async {
    if (amountMinor <= 0 || amountMinor > Money.maxMinor) {
      throw const AppException(
        'จำนวนเงินต้องมากกว่า 0 และอยู่ในวงเงินที่รองรับ',
      );
    }
    final localDate = DateTime(date.year, date.month, date.day);
    if (localDate.isAfter(AppDates.today()) || date.year < 1900) {
      throw const AppException('เลือกวันที่วันนี้หรือวันที่ผ่านมา');
    }
    if ((note?.length ?? 0) > 500) {
      throw const AppException('หมายเหตุต้องไม่เกิน 500 ตัวอักษร');
    }
    final db = await database.instance;
    return db.transaction((txn) async {
      final debts = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      if (debts.isEmpty) throw const AppException('ไม่พบบัญชีนี้');
      final borrowed = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM borrowings WHERE debt_id = ?',
        [debtId],
      );
      final paid = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM payments WHERE debt_id = ?',
        [debtId],
      );
      final total =
          (debts.first['initial_amount_minor'] as int) +
          (borrowed.first['total'] as int);
      if (amountMinor > Money.maxMinor - total) {
        throw AppException(
          DebtWording(
            DebtDirection.values.byName(debts.first['direction'] as String),
          ).overflow,
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.insert('borrowings', {
        'id': const Uuid().v4(),
        'debt_id': debtId,
        'amount_minor': amountMinor,
        'borrowing_date': AppDates.storage(localDate),
        'note': note?.trim(),
        'created_at': now,
      });
      await txn.update(
        'debts',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [debtId],
      );
      return BorrowingReceipt(
        amountMinor: amountMinor,
        previousRemaining: total - (paid.first['total'] as int),
      );
    });
  }

  Future<void> update({
    required String id,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) async {
    if (amountMinor <= 0 || amountMinor > Money.maxMinor) {
      throw const AppException(
        'จำนวนเงินต้องมากกว่า 0 และอยู่ในวงเงินที่รองรับ',
      );
    }
    final localDate = DateTime(date.year, date.month, date.day);
    if (localDate.isAfter(AppDates.today()) || date.year < 1900) {
      throw const AppException('เลือกวันที่วันนี้หรือวันที่ผ่านมา');
    }
    if ((note?.length ?? 0) > 500) {
      throw const AppException('หมายเหตุต้องไม่เกิน 500 ตัวอักษร');
    }
    final db = await database.instance;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'borrowings',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        throw const AppException('ไม่พบรายการนี้ อาจถูกลบไปแล้ว');
      }
      final row = rows.single;
      final storedDate = AppDates.storage(localDate);
      final trimmedNote = note?.trim() ?? '';
      if (row['amount_minor'] == amountMinor &&
          row['borrowing_date'] == storedDate &&
          ((row['note'] as String?)?.trim() ?? '') == trimmedNote) {
        return;
      }
      final debtId = row['debt_id'] as String;
      final debts = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      if (debts.isEmpty) throw const AppException('ไม่พบบัญชีนี้');
      final borrowedRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM borrowings WHERE debt_id = ?',
        [debtId],
      );
      final paidRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM payments WHERE debt_id = ?',
        [debtId],
      );
      final total =
          (debts.single['initial_amount_minor'] as int) +
          (borrowedRows.single['total'] as int);
      final paid = paidRows.single['total'] as int;
      final totalAfter = total - (row['amount_minor'] as int) + amountMinor;
      if (totalAfter > Money.maxMinor) {
        throw AppException(
          DebtWording(
            DebtDirection.values.byName(debts.first['direction'] as String),
          ).overflow,
        );
      }
      if (totalAfter < paid) {
        throw AppException(
          DebtWording(
            DebtDirection.values.byName(debts.first['direction'] as String),
          ).cannotEditBorrowing,
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'borrowings',
        {
          'amount_minor': amountMinor,
          'borrowing_date': storedDate,
          'note': trimmedNote,
          'is_edited': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'debts',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [debtId],
      );
    });
  }

  Future<bool> delete(String id) async {
    final db = await database.instance;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'borrowings',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return false;
      final row = rows.first;
      final debtId = row['debt_id'] as String;
      final debts = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      final borrowed = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM borrowings WHERE debt_id = ?',
        [debtId],
      );
      final paid = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM payments WHERE debt_id = ?',
        [debtId],
      );
      final totalAfter =
          (debts.first['initial_amount_minor'] as int) +
          (borrowed.first['total'] as int) -
          (row['amount_minor'] as int);
      if (totalAfter < (paid.first['total'] as int)) {
        throw AppException(
          DebtWording(
            DebtDirection.values.byName(debts.first['direction'] as String),
          ).cannotDeleteBorrowing,
        );
      }
      await txn.delete('borrowings', where: 'id = ?', whereArgs: [id]);
      await txn.update(
        'debts',
        {'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [debtId],
      );
      return true;
    });
  }
}
