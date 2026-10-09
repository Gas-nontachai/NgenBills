import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

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
  Future<List<Debt>> list() async {
    final db = await database.instance;
    return (await db.query(
      'debts',
      orderBy: 'created_at ASC, id ASC',
    )).map(Debt.fromMap).toList(growable: false);
  }

  Future<String?> defaultId() async {
    final db = await database.instance;
    return db.transaction(_resolveDefault);
  }

  Future<String?> _resolveDefault(DatabaseExecutor txn) async {
    final rows = await txn.query('debts', orderBy: 'created_at ASC, id ASC');
    final prefs = await txn.query(
      'app_preferences',
      where: 'key = ?',
      whereArgs: ['default_debt_id'],
    );
    final saved = prefs.isEmpty ? null : prefs.single['value'] as String;
    final id = rows.any((r) => r['id'] == saved)
        ? saved
        : rows.firstOrNull?['id'] as String?;
    if (id == null) {
      await txn.delete(
        'app_preferences',
        where: 'key = ?',
        whereArgs: ['default_debt_id'],
      );
    } else if (saved != id) {
      await _writeDefault(txn, id);
    }
    return id;
  }

  Future<void> _writeDefault(DatabaseExecutor txn, String id) => txn
      .insert('app_preferences', {
        'key': 'default_debt_id',
        'value': id,
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});

  Future<void> setDefault(String id) async {
    final db = await database.instance;
    await db.transaction((txn) async {
      if ((await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [id],
      )).isEmpty) {
        throw const AppException('ไม่พบบัญชีนี้');
      }
      await _writeDefault(txn, id);
    });
  }

  Future<List<DebtSummary>> loadAll() async {
    final db = await database.instance;
    return db.transaction((txn) async {
      final debts = await txn.query('debts', orderBy: 'created_at ASC, id ASC');
      return Future.wait(debts.map((row) => _summary(txn, Debt.fromMap(row))));
    });
  }

  Future<DebtSummary> _summary(DatabaseExecutor txn, Debt debt) async {
    final payments = await txn.query(
      'payments',
      where: 'debt_id = ?',
      whereArgs: [debt.id],
      orderBy: 'payment_date DESC, created_at DESC, id DESC',
    );
    final borrowings = await txn.query(
      'borrowings',
      where: 'debt_id = ?',
      whereArgs: [debt.id],
    );
    return DebtSummary(
      debt,
      payments.map(Payment.fromMap).toList(),
      borrowings.map(Borrowing.fromMap).toList(),
    );
  }

  Future<DebtSummary?> load([String? debtId]) async {
    final db = await database.instance;
    return db.transaction((txn) async {
      final debts = await txn.query(
        'debts',
        where: debtId == null ? null : 'id = ?',
        whereArgs: debtId == null ? null : [debtId],
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

  Future<String> create({
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
    return db.transaction((txn) async {
      final id = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.insert('debts', {
        'id': id,
        'name': clean,
        'initial_amount_minor': amountMinor,
        'note': note?.trim(),
        'created_at': now,
        'updated_at': now,
      });
      await _resolveDefault(txn);
      return id;
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
    return db.transaction((txn) async {
      final deleted =
          await txn.delete('debts', where: 'id = ?', whereArgs: [debtId]) > 0;
      await _resolveDefault(txn);
      return deleted;
    });
  }
}
