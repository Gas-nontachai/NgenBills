import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/reminder_fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late ProviderContainer container;
  late FakeNotificationService service;
  late ReminderController controller;
  late String debtId;
  setUp(() async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    service = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(service),
        reminderClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 8),
        ),
      ],
    );
    controller = container.read(reminderControllerProvider.notifier);
    await container
        .read(debtRepositoryProvider)
        .create(name: 'บัตรเครดิต', amountMinor: 1000000);
    debtId = (await container.read(debtRepositoryProvider).load())!.debt.id;
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
  });
  ReminderSettings settings({int day = 27, int hour = 9}) =>
      ReminderSettings(debtId: debtId, dueDay: day, enabled: true, hour: hour);

  test(
    'No automatic permission prompt; onboarding skip persists separately',
    () async {
      await controller.refresh();
      expect(container.read(reminderControllerProvider).onboardingDone, false);
      expect(container.read(reminderControllerProvider).settings, isNull);
      expect(service.requests, 0);
      expect(service.pending, isEmpty);
      await controller.completeOnboarding(enable: false);
      expect(
        await container.read(reminderRepositoryProvider).onboardingDone(),
        true,
      );
      expect(service.requests, 0);
    },
  );

  test(
    'Partial payment updates amounts, full payment cancels, deletion restores',
    () async {
      await controller.save(settings());
      expect(service.pending, hasLength(48));
      expect(service.pending.first.body, contains('฿10,000'));
      final payments = container.read(paymentRepositoryProvider);
      await payments.add(
        debtId: debtId,
        amountMinor: 300000,
        date: DateTime(2026, 10, 8),
      );
      await controller.refresh();
      expect(service.pending.first.body, contains('฿7,000'));
      expect(service.pending, hasLength(48));
      await payments.add(
        debtId: debtId,
        amountMinor: 700000,
        date: DateTime(2026, 10, 8),
      );
      await controller.refresh();
      expect(service.pending, isEmpty);
      final payment =
          (await container.read(debtRepositoryProvider).load())!.payments.first;
      await payments.delete(payment.id);
      await controller.refresh();
      expect(service.pending, isNotEmpty);
      expect(service.pending.first.body, contains('ยอดหนี้คงเหลือ'));
    },
  );

  test(
    'Rapid saves and refreshes leave the latest schedule without duplicates',
    () async {
      await Future.wait([
        controller.save(settings(day: 20)),
        controller.refresh(),
        controller.save(settings(day: 31, hour: 14)),
        controller.refresh(),
      ]);
      expect(service.pending, hasLength(48));
      expect(service.pending.map((r) => r.id).toSet(), hasLength(48));
      expect(service.pending.every((r) => r.at.hour == 14), true);
      expect(service.pending.first.dueDate.day, 31);
      expect(
        (await container.read(reminderRepositoryProvider).load(debtId))!.dueDay,
        31,
      );
    },
  );

  test('Native failure preserves committed settings; retry recovers', () async {
    service.failSchedule = true;
    await controller.save(settings());
    expect(
      (await container.read(reminderRepositoryProvider).load(debtId))!.enabled,
      true,
    );
    expect(container.read(reminderControllerProvider).syncError, true);
    expect(container.read(reminderControllerProvider).permissionAllowed, true);
    service.failSchedule = false;
    await controller.refresh();
    expect(container.read(reminderControllerProvider).syncError, false);
    expect(service.pending, hasLength(48));
  });

  test('Permission revocation clears schedule; grant and timezone change rebuild it', () async {
    await controller.save(settings());
    final originalInstant = service.pending.first.at;
    service.allowed = false;
    await controller.refresh();
    expect(container.read(reminderControllerProvider).permissionAllowed, false);
    expect(container.read(reminderControllerProvider).settings!.enabled, true);
    expect(service.pending, isEmpty);
    service.zoneName = 'America/New_York';
    expect(await controller.requestPermission(), true);
    expect(service.pending.first.at.hour, 9);
    expect(service.pending.first.at.isAtSameMomentAs(originalInstant), false);
    expect(service.requests, 1);
    await controller.disable();
    expect(service.pending, isEmpty);
    final stored = (await container
        .read(reminderRepositoryProvider)
        .load(debtId))!;
    expect(stored.enabled, false);
    expect(stored.dueDay, 27);
    expect(stored.advanceDays, {3});
  });

  test(
    'Failed database save throws without replacing existing reminders',
    () async {
      final repository = MemoryReminderRepository();
      final isolated = ProviderContainer(
        overrides: [
          debtRepositoryProvider.overrideWithValue(
            container.read(debtRepositoryProvider),
          ),
          reminderRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(service),
          reminderClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 8),
          ),
        ],
      );
      addTearDown(isolated.dispose);
      final action = isolated.read(reminderControllerProvider.notifier);
      await action.save(settings());
      final before = service.pending.map((r) => r.id).toList();
      repository.failWrites = true;
      await expectLater(action.save(settings(day: 31)), throwsStateError);
      expect(service.pending.map((r) => r.id), before);
      expect(repository.settings[debtId]!.dueDay, 27);
    },
  );

  test('Permission denial preserves intent without scheduling; retry handles native startup failure', () async {
    await controller.save(settings());
    service.grantOnRequest = false;
    expect(await controller.requestPermission(), false);
    expect(service.pending, isEmpty);
    expect(
      (await container.read(reminderRepositoryProvider).load(debtId))!.enabled,
      true,
    );
    service.failInitialize = true;
    await controller.refresh();
    expect(container.read(reminderControllerProvider).syncError, true);
    expect(
      container.read(reminderControllerProvider).permissionAllowed,
      isNull,
    );
    service.failInitialize = false;
    service.grantOnRequest = true;
    expect(await controller.requestPermission(), true);
    expect(container.read(reminderControllerProvider).syncError, false);
    expect(service.pending, hasLength(48));
  });
}
