import 'package:sqflite/sqflite.dart';

Future<void> createSchema(Database db) async {
  await db.execute("""CREATE TABLE debts (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),
    initial_amount_minor INTEGER NOT NULL CHECK(initial_amount_minor > 0 AND initial_amount_minor <= 99999999999999),
    note TEXT CHECK(note IS NULL OR length(note) <= 500),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )""");
  await db.execute("""CREATE TABLE payments (
    id TEXT PRIMARY KEY NOT NULL,
    debt_id TEXT NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0 AND amount_minor <= 99999999999999),
    payment_date TEXT NOT NULL,
    note TEXT CHECK(note IS NULL OR length(note) <= 500),
    created_at TEXT NOT NULL
  )""");
  await db.execute(
    'CREATE INDEX payments_debt_date ON payments(debt_id, payment_date DESC, created_at DESC)',
  );
  await createReminderSchema(db);
  await db.execute('''CREATE TABLE app_preferences (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
  )''');
}

Future<void> createReminderSchema(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE reminder_settings (
    debt_id TEXT PRIMARY KEY NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    due_day INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 31),
    advance_days_mask INTEGER NOT NULL CHECK(advance_days_mask BETWEEN 0 AND 7),
    hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23),
    minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59),
    enabled INTEGER NOT NULL CHECK(enabled IN (0, 1)),
    remind_on_due_date INTEGER NOT NULL CHECK(remind_on_due_date IN (0, 1))
  )''');
}

Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE reminder_settings RENAME TO reminder_settings_v1',
    );
    await createReminderSchema(db);
    await db.execute('''INSERT INTO reminder_settings
      (debt_id, due_day, advance_days_mask, hour, minute, enabled, remind_on_due_date)
      SELECT debt_id, due_day,
        CASE days_before WHEN 1 THEN 1 WHEN 3 THEN 2 WHEN 7 THEN 4 ELSE 0 END,
        hour, minute, enabled, remind_on_due_date FROM reminder_settings_v1''');
    await db.execute('DROP TABLE reminder_settings_v1');
  }
}
