import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/borrowing.dart';
import '../../domain/entities/account_appearance.dart';
import '../../domain/services/debt_summary.dart';
import '../../../payment/domain/entities/payment.dart';

class DebtRepository {
  DebtRepository(this.database);
  final AppDatabase database;
  Future<DebtSummary?> load() async {
    final db = await database.instance;
    return db.transaction((txn) async {
      final debts = await txn.query(
        'debts',
        orderBy: 'created_at ASC, id ASC',
        limit: 1,
      );
      if (debts.isEmpty) return null;
      final debt = Debt.fromMap(debts.first);
      final rows = await txn.query(
        'payments',
        where: 'debt_id = ?',
        whereArgs: [debt.id],
        orderBy: 'payment_date DESC, created_at DESC, id DESC',
      );
      final borrowingRows = await txn.query(
        'borrowings',
        where: 'debt_id = ?',
        whereArgs: [debt.id],
      );
      return DebtSummary(
        debt,
        rows.map(Payment.fromMap).toList(growable: false),
        borrowingRows.map(Borrowing.fromMap).toList(growable: false),
      );
    });
  }

  Future<void> create({
    required String name,
    required int amountMinor,
    String? note,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 100) {
      throw const AppException('ชื่อหนี้ต้องมี 1–100 ตัวอักษร');
    }
    if (amountMinor <= 0 || amountMinor > Money.maxMinor) {
      throw const AppException('ยอดหนี้ไม่ถูกต้อง');
    }
    if ((note?.length ?? 0) > 500) {
      throw const AppException('หมายเหตุต้องไม่เกิน 500 ตัวอักษร');
    }
    final db = await database.instance;
    await db.transaction((txn) async {
      if ((await txn.query('debts', limit: 1)).isNotEmpty) {
        throw const AppException('คุณมีหนี้ที่ติดตามอยู่แล้ว');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.insert('debts', {
        'id': const Uuid().v4(),
        'name': clean,
        'initial_amount_minor': amountMinor,
        'note': note?.trim(),
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<void> customize({
    required String debtId,
    required String name,
    required String iconKey,
    required String colorKey,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 100) {
      throw const AppException('ชื่อบัญชีต้องมี 1–100 ตัวอักษร');
    }
    if (!AccountAppearance.iconKeys.contains(iconKey) ||
        !AccountAppearance.colorKeys.contains(colorKey)) {
      throw const AppException('ไอคอนหรือสีไม่ถูกต้อง');
    }
    final db = await database.instance;
    await db.transaction((txn) async {
      final count = await txn.update(
        'debts',
        {
          'name': clean,
          'icon_key': iconKey,
          'color_key': colorKey,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );
      if (count == 0) throw const AppException('ไม่พบบัญชีนี้');
    });
  }

  Future<bool> delete(String debtId) async {
    final db = await database.instance;
    return db.transaction(
      (txn) async =>
          await txn.delete('debts', where: 'id = ?', whereArgs: [debtId]) > 0,
    );
  }
}
