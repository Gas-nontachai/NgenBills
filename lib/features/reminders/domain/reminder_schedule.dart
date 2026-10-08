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
        if (settings.daysBefore > 0) settings.daysBefore,
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
            // One debt in this MVP; IDs identify the due month + reminder kind.
            id: (due.year * 12 + due.month) * 2 + (offset == 0 ? 0 : 1),
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
    return result;
  }
}
