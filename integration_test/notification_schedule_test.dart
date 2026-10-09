import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/reminders/data/notification_service.dart';
import 'package:ngenbills/features/reminders/domain/reminder_schedule.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native scheduling: replace multi-offset schedule, update amount and cancel',
    (tester) async {
      final service = LocalNotificationService(onTap: (_) {});
      final plugin = FlutterLocalNotificationsPlugin();
      await service.initialize();
      final zone = await service.localTimezone();
      final now = tz.TZDateTime.now(zone);
      final debt = Debt(
        id: 'notification-native-test',
        name: 'หนี้ทดสอบ',
        initialAmountMinor: 1000000,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final settings = ReminderSettings(
        debtId: debt.id,
        advanceDays: const {1, 3, 7},
        dueDay: DateTime(now.year, now.month + 1, 0).day,
        enabled: true,
        hour: 23,
        minute: 59,
      );
      final schedule = ReminderSchedule.build(
        summary: DebtSummary(debt, []),
        settings: settings,
        now: now,
      );
      try {
        // iOS rejects scheduling without authorization. Provisional permission
        // allows native pending-request verification without an alert prompt.
        // Run this test on a simulator/test device, as documented in README.
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            !await service.permissionAllowed()) {
          final allowed = await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()!
              .requestPermissions(alert: true, sound: true, provisional: true);
          expect(allowed, true);
        }
        await service.replaceSchedule(schedule);
        var pending = await plugin.pendingNotificationRequests();
        expect(pending.length, schedule.length);
        expect(pending.map((r) => r.id).toSet().length, schedule.length);
        expect(pending.every((r) => r.body!.contains('฿10,000')), true);
        final updatedDebt = Debt(
          id: debt.id,
          name: debt.name,
          initialAmountMinor: 700000,
          createdAt: debt.createdAt,
          updatedAt: debt.updatedAt,
        );
        final updated = ReminderSchedule.build(
          summary: DebtSummary(updatedDebt, []),
          settings: settings,
          now: now,
        );
        await service.replaceSchedule(updated);
        pending = await plugin.pendingNotificationRequests();
        expect(pending.length, updated.length);
        expect(pending.every((r) => r.body!.contains('฿7,000')), true);
        expect(
          pending.map((r) => r.id).toSet(),
          schedule.map((r) => r.id).toSet(),
        );
        final secondDebt = Debt(
          id: 'notification-second-test',
          name: 'second account',
          initialAmountMinor: 2000000,
          createdAt: debt.createdAt,
          updatedAt: debt.updatedAt,
        );
        final merged = ReminderSchedule.combine([
          ...updated,
          ...ReminderSchedule.build(
            summary: DebtSummary(secondDebt, []),
            settings: ReminderSettings(
              debtId: secondDebt.id,
              dueDay: settings.dueDay,
              enabled: true,
              advanceDays: {1, 3, 7},
              hour: 23,
              minute: 59,
            ),
            now: now,
          ),
        ]);
        await service.replaceSchedule(merged);
        pending = await plugin.pendingNotificationRequests();
        expect(pending.length, 60);
        expect(pending.map((r) => r.id).toSet().length, 60);
        expect(pending.map((r) => r.payload).toSet(), {debt.id, secondDebt.id});
        await service.replaceSchedule([]);
        expect(await plugin.pendingNotificationRequests(), isEmpty);
      } finally {
        await service.replaceSchedule([]);
      }
    },
  );
}
