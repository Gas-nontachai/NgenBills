import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/features/payment/domain/entities/payment.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/reminders/domain/reminder_schedule.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

DebtSummary reminderDebt() => DebtSummary(
  Debt(
    id: 'debt',
    name: 'บัตรเครดิต',
    initialAmountMinor: 1000000,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
  [],
);

void main() {
  setUpAll(tzdata.initializeTimeZones);
  test(
    '24 calendar months, two unique stable IDs per month and selected minute',
    () {
      final now = tz.TZDateTime(tz.getLocation('Asia/Bangkok'), 2026, 10, 8);
      const settings = ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        hour: 14,
        minute: 37,
        enabled: true,
      );
      final schedule = ReminderSchedule.build(
        summary: reminderDebt(),
        settings: settings,
        now: now,
      );
      expect(schedule, hasLength(48));
      expect(schedule.first.at.day, 24);
      expect(schedule.first.at.hour, 14);
      expect(schedule.first.at.minute, 37);
      expect(schedule.first.at.location.name, 'Asia/Bangkok');
      expect(schedule.last.dueDate.year, 2028);
      expect(schedule.last.dueDate.month, 9);
      expect(schedule.map((r) => r.id).toSet(), hasLength(48));
      expect(schedule.first.title, contains('อีก 3 วัน'));
      expect(schedule.first.body, contains('฿10,000'));
      final repeated = ReminderSchedule.build(
        summary: reminderDebt(),
        settings: settings,
        now: now,
      );
      expect(repeated.map((r) => r.id), schedule.map((r) => r.id));
    },
  );

  test('Multiple offsets schedule nearest 60 with unique stable IDs', () {
    final now = tz.TZDateTime(tz.getLocation('Asia/Bangkok'), 2026, 10, 8);
    final schedule = ReminderSchedule.build(
      summary: reminderDebt(),
      settings: const ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        advanceDays: {1, 7, 3},
        enabled: true,
      ),
      now: now,
    );
    expect(schedule, hasLength(60));
    expect(schedule.map((r) => r.id).toSet(), hasLength(60));
    expect(schedule.take(4).map((r) => r.daysBefore), [7, 3, 1, 0]);
    for (var i = 1; i < schedule.length; i++) {
      expect(schedule[i].at.isAfter(schedule[i - 1].at), true);
    }
    final reversed = ReminderSchedule.build(
      summary: reminderDebt(),
      settings: const ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        advanceDays: {3, 7, 1},
        enabled: true,
      ),
      now: now,
    );
    expect(reversed.map((r) => r.id), schedule.map((r) => r.id));
    final paid = DebtSummary(reminderDebt().debt, [
      Payment(
        id: 'p',
        debtId: 'debt',
        amountMinor: 1000000,
        date: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
      ),
    ]);
    expect(
      ReminderSchedule.build(
        summary: paid,
        settings: const ReminderSettings(
          debtId: 'debt',
          dueDay: 27,
          advanceDays: {1, 3, 7},
          enabled: true,
        ),
        now: now,
      ),
      isEmpty,
    );
  });

  test(
    '31 clamps to month end, including leap February; advance can cross year',
    () {
      final zone = tz.getLocation('Asia/Bangkok');
      expect(ReminderSchedule.dueDate(zone, 2027, 2, 31).day, 28);
      expect(ReminderSchedule.dueDate(zone, 2028, 2, 31).day, 29);
      expect(ReminderSchedule.dueDate(zone, 2026, 4, 31).day, 30);
      final schedule = ReminderSchedule.build(
        summary: reminderDebt(),
        settings: const ReminderSettings(
          debtId: 'debt',
          dueDay: 2,
          advanceDays: {7},
          enabled: true,
        ),
        now: tz.TZDateTime(zone, 2026, 12, 20),
      );
      expect(schedule.first.at.year, 2026);
      expect(schedule.first.at.month, 12);
      expect(schedule.first.at.day, 26);
      expect(schedule.first.dueDate.year, 2027);
      expect(schedule.first.dueDate.month, 1);
    },
  );

  test(
    'Skip past or equal times; due today stays visible after reminder time',
    () {
      final zone = tz.getLocation('Asia/Bangkok');
      const settings = ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        enabled: true,
      );
      final now = tz.TZDateTime(zone, 2026, 10, 27, 9);
      final schedule = ReminderSchedule.build(
        summary: reminderDebt(),
        settings: settings,
        now: now,
      );
      expect(schedule.every((r) => r.at.isAfter(now)), true);
      expect(schedule.first.dueDate.month, 11);
      expect(
        ReminderSchedule.daysUntil(
          ReminderSchedule.nextDueDate(settings, now),
          now,
        ),
        0,
      );
    },
  );

  test('No lead reminder, no due-day reminder, and disabled settings', () {
    final now = tz.TZDateTime(tz.UTC, 2026, 10, 8);
    List<ScheduledReminder> build(ReminderSettings settings) =>
        ReminderSchedule.build(
          summary: reminderDebt(),
          settings: settings,
          now: now,
        );
    expect(
      build(
        const ReminderSettings(
          debtId: 'debt',
          dueDay: 27,
          advanceDays: {},
          enabled: true,
        ),
      ),
      hasLength(24),
    );
    expect(
      build(
        const ReminderSettings(
          debtId: 'debt',
          dueDay: 27,
          enabled: true,
          remindOnDueDate: false,
        ),
      ),
      hasLength(24),
    );
    expect(
      build(
        const ReminderSettings(
          debtId: 'debt',
          dueDay: 27,
          advanceDays: {},
          enabled: true,
          remindOnDueDate: false,
        ),
      ),
      isEmpty,
    );
    expect(build(const ReminderSettings(debtId: 'debt', dueDay: 27)), isEmpty);
    expect(
      () => build(const ReminderSettings(debtId: 'debt', dueDay: 32)),
      throwsArgumentError,
    );
  });

  test(
    'Local hour and calendar countdown survive DST and timezone changes',
    () {
      const settings = ReminderSettings(
        debtId: 'debt',
        dueDay: 10,
        enabled: true,
        advanceDays: {3},
        hour: 9,
        minute: 12,
      );
      final zone = tz.getLocation('America/New_York');
      final now = tz.TZDateTime(zone, 2026, 3, 6, 23);
      final schedule = ReminderSchedule.build(
        summary: reminderDebt(),
        settings: settings,
        now: now,
      );
      expect(schedule.first.at.day, 7);
      expect(schedule.first.at.hour, 9);
      expect(schedule[1].at.hour, 9);
      expect(schedule.first.at.timeZoneOffset, const Duration(hours: -5));
      expect(schedule[1].at.timeZoneOffset, const Duration(hours: -4));
      expect(ReminderSchedule.daysUntil(schedule[1].dueDate, now), 4);
      final bangkok = ReminderSchedule.build(
        summary: reminderDebt(),
        settings: settings,
        now: tz.TZDateTime(tz.getLocation('Asia/Bangkok'), 2026, 3, 6, 23),
      );
      expect(bangkok.first.at.hour, 9);
      expect(bangkok.first.at.isAtSameMomentAs(schedule.first.at), false);
    },
  );
}
