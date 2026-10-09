import 'package:timezone/timezone.dart' as tz;

import '../../debt/domain/services/debt_summary.dart';
import '../../../core/formatters/currency_formatter.dart';
import 'reminder_settings.dart';

class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.at,
    required this.dueDate,
    required this.daysBefore,
    required this.title,
    required this.body,
    required this.debtId,
  });
  final int id, daysBefore;
  final tz.TZDateTime at, dueDate;
  final String title, body, debtId;
}

abstract final class ReminderSchedule {
  // IDs are assigned after merging; every replacement first cancels the old schedule.
  static List<ScheduledReminder> combine(List<ScheduledReminder> reminders) {
    reminders.sort((a, b) {
      final time = a.at.compareTo(b.at);
      if (time != 0) return time;
      final debt = a.debtId.compareTo(b.debtId);
      return debt != 0 ? debt : a.id.compareTo(b.id);
    });
    return [
      for (final (index, r) in reminders.take(60).indexed)
        ScheduledReminder(
          id: index + 1,
          at: r.at,
          dueDate: r.dueDate,
          daysBefore: r.daysBefore,
          title: r.title,
          body: r.body,
          debtId: r.debtId,
        ),
    ];
  }

  static tz.TZDateTime dueDate(tz.Location zone, int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return tz.TZDateTime(zone, year, month, day.clamp(1, lastDay));
  }

  static tz.TZDateTime nextDueDate(
    ReminderSettings settings,
    tz.TZDateTime now,
  ) {
    var due = dueDate(now.location, now.year, now.month, settings.dueDay);
    final today = tz.TZDateTime(now.location, now.year, now.month, now.day);
    if (due.isBefore(today)) {
      due = dueDate(now.location, now.year, now.month + 1, settings.dueDay);
    }
    return due;
  }

  // Count calendar days, rather than elapsed hours (DST days may not be 24h).
  static int daysUntil(tz.TZDateTime date, tz.TZDateTime now) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

  static List<ScheduledReminder> build({
    required DebtSummary summary,
    required ReminderSettings settings,
    required tz.TZDateTime now,
  }) {
    settings.validate();
    if (!settings.enabled || summary.isPaid) return [];
    final first = nextDueDate(settings, now);
    final result = <ScheduledReminder>[];
    for (var i = 0; i < 24; i++) {
      final due = dueDate(
        now.location,
        first.year,
        first.month + i,
        settings.dueDay,
      );
      final offsets = [
        ...settings.advanceDays,
        if (settings.remindOnDueDate) 0,
      ];
      for (final offset in offsets) {
        // Subtract calendar days BEFORE constructing the zoned time to avoid
        // shifting the selected hour across a daylight-saving transition.
        final localDate = DateTime.utc(due.year, due.month, due.day - offset);
        final at = tz.TZDateTime(
          now.location,
          localDate.year,
          localDate.month,
          localDate.day,
          settings.hour,
          settings.minute,
        );
        if (!at.isAfter(now)) continue;
        final heading = offset == 0
            ? 'วันนี้ถึงวันชำระ'
            : 'อีก $offset วันถึงวันชำระ';
        result.add(
          ScheduledReminder(
            // Candidate ID identifies month and offset; combine assigns native IDs.
            id: (due.year * 12 + due.month) * 8 + offset,
            at: at,
            dueDate: due,
            daysBefore: offset,
            debtId: summary.debt.id,
            title: '$heading${summary.debt.name}',
            body:
                'ครบกำหนดวันที่ ${due.day}/${due.month}/${due.year + 543} · '
                'ยอดหนี้คงเหลือ ${Money.format(summary.remaining)} 🌱',
          ),
        );
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result.take(60).toList();
  }
}
