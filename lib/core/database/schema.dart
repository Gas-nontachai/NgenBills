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
  await db.execute('''CREATE TABLE reminder_settings (
    debt_id TEXT PRIMARY KEY NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
    due_day INTEGER NOT NULL CHECK(due_day BETWEEN 1 AND 31),
    days_before INTEGER NOT NULL CHECK(days_before IN (0, 1, 3, 7)),
    hour INTEGER NOT NULL CHECK(hour BETWEEN 0 AND 23),
    minute INTEGER NOT NULL CHECK(minute BETWEEN 0 AND 59),
    enabled INTEGER NOT NULL CHECK(enabled IN (0, 1)),
    remind_on_due_date INTEGER NOT NULL CHECK(remind_on_due_date IN (0, 1))
  )''');
  await db.execute('''CREATE TABLE app_preferences (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL
  )''');
}
