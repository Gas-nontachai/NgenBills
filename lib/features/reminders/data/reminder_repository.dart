import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/reminder_settings.dart';

class ReminderRepository {
  ReminderRepository(this.database);
  final AppDatabase database;

  Future<ReminderSettings?> load(String debtId) async {
    final rows = await (await database.instance).query(
      'reminder_settings',
      where: 'debt_id = ?',
      whereArgs: [debtId],
    );
    return rows.isEmpty ? null : ReminderSettings.fromMap(rows.single);
  }

  Future<void> save(ReminderSettings settings) async {
    settings.validate();
    await (await database.instance).insert(
      'reminder_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> disableAll() async {
    final db = await database.instance;
    await db.transaction((txn) async {
      await txn.update('reminder_settings', {'enabled': 0});
    });
  }

  Future<bool> onboardingDone() async {
    final rows = await (await database.instance).query(
      'app_preferences',
      where: 'key = ?',
      whereArgs: ['notification_onboarding_done'],
    );
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  Future<void> completeOnboarding() async {
    await (await database.instance).insert('app_preferences', {
      'key': 'notification_onboarding_done',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
