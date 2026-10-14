import '../../../debt/domain/services/debt_wording.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/formatters/currency_formatter.dart';

class PaymentRepository {
  PaymentRepository(this.database);
  final AppDatabase database;
  Future<void> add({
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
    await db.transaction((txn) async {
      final rows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      if (rows.isEmpty) throw const AppException('ไม่พบหนี้รายการนี้');
      final totals = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS paid FROM payments WHERE debt_id = ?',
        [debtId],
      );
      final borrowed = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount_minor), 0) AS total FROM borrowings WHERE debt_id = ?',
        [debtId],
      );
      final remaining =
          (rows.first['initial_amount_minor'] as int) +
          (borrowed.first['total'] as int) -
          (totals.first['paid'] as int);
      if (amountMinor > remaining) {
        throw AppException(
          DebtWording(
            DebtDirection.values.byName(rows.first['direction'] as String),
          ).overRemaining(Money.format(remaining)),
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      if (amountMinor == remaining) {
        await txn.update(
          'reminder_settings',
          {'enabled': 0},
          where: 'debt_id = ?',
          whereArgs: [debtId],
        );
      }
      await txn.insert('payments', {
        'id': const Uuid().v4(),
        'debt_id': debtId,
        'amount_minor': amountMinor,
        'payment_date': AppDates.storage(localDate),
        'note': note?.trim(),
        'created_at': now,
      });
      await txn.update(
        'debts',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [debtId],
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
        'payments',
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
          row['payment_date'] == storedDate &&
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
      final limit = total - paid + (row['amount_minor'] as int);
      if (amountMinor > limit) {
        throw AppException(
          'จำนวนเงินเกินยอดที่แก้ไขได้ ${Money.format(limit)}',
        );
      }

      if (amountMinor == limit) {
        await txn.update(
          'reminder_settings',
          {'enabled': 0},
          where: 'debt_id = ?',
          whereArgs: [debtId],
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'payments',
        {
          'amount_minor': amountMinor,
          'payment_date': storedDate,
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
        'payments',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return false;
      await txn.delete('payments', where: 'id = ?', whereArgs: [id]);
      await txn.update(
        'debts',
        {'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [rows.first['debt_id']],
      );
      return true;
    });
  }
}
