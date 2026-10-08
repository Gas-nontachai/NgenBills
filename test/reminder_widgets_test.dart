import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_settings_sheet.dart';

import 'support/reminder_fakes.dart';

class _DebtRepository extends DebtRepository {
  _DebtRepository() : super(AppDatabase(factory: databaseFactoryFfi));
  int amountMinor = 1000000;
  @override
  Future<DebtSummary?> load() async => DebtSummary(
    Debt(
      id: 'debt',
      name: 'บัตรเครดิต',
      initialAmountMinor: amountMinor,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    [],
  );
}

void main() {
  late MemoryReminderRepository repository;
  late FakeNotificationService service;
  late _DebtRepository debts;
  setUp(() {
    debts = _DebtRepository();
    repository = MemoryReminderRepository();
    service = FakeNotificationService();
  });
  Future<void> boot(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool Function()? failHomeRead,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debtRepositoryProvider.overrideWithValue(debts),
          if (failHomeRead != null)
            debtSummaryProvider.overrideWith((ref) async {
              if (failHomeRead()) throw StateError('Home read failed');
              return debts.load();
            }),
          reminderRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(service),
          reminderClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 8),
          ),
        ],
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Onboarding skip persists and never prompts permission on resume',
    (tester) async {
      repository.done = false;
      await boot(tester);
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsOneWidget);
      expect(service.requests, 0);
      await tap(tester, find.text('ไว้ทีหลัง'));
      expect(repository.done, true);
      expect(find.text('ตั้งวันครบกำหนดและแจ้งเตือน'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsNothing);
      expect(service.requests, 0);
    },
  );

  testWidgets(
    'Onboarding enable requests once and opens configuration without guessing a day',
    (tester) async {
      repository.done = false;
      await boot(tester);
      await tap(tester, find.text('เปิดการแจ้งเตือน'));
      expect(service.requests, 1);
      expect(repository.done, true);
      expect(find.byType(ReminderSettingsSheet), findsOneWidget);
      expect(repository.settings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Choose day and minute, save, reopen, and cancel unsaved changes',
    (tester) async {
      await boot(tester);
      await tap(tester, find.text('ตั้งวันครบกำหนดและแจ้งเตือน'));
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'บันทึกการตั้งค่า'),
      );
      expect(save.onPressed, isNull);
      await tap(tester, find.byType(DropdownButtonFormField<int>).first);
      await tap(tester, find.text('วันที่ 1 ของทุกเดือน').last);
      await tap(tester, find.text('เวลาแจ้งเตือน 09:00 น.'));
      final inputs = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      expect(inputs, findsNWidgets(2));
      await tester.enterText(inputs.at(0), '14');
      await tester.enterText(inputs.at(1), '37');
      await tap(tester, find.text('ตกลง').last);
      await tap(tester, find.byType(SwitchListTile));
      expect(service.requests, 1);
      await tap(tester, find.text('บันทึกการตั้งค่า'));
      expect(repository.settings['debt']!.dueDay, 1);
      expect(repository.settings['debt']!.hour, 14);
      expect(repository.settings['debt']!.minute, 37);
      expect(repository.settings['debt']!.enabled, true);
      expect(service.pending, isNotEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tap(tester, find.text('ครบกำหนดวันที่ 1 ของเดือน'));
      expect(find.text('เวลาแจ้งเตือน 14:37 น.'), findsOneWidget);
      await tap(tester, find.byType(CheckboxListTile));
      await tap(tester, find.byIcon(Icons.close));
      expect(repository.settings['debt']!.remindOnDueDate, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Denied permission is distinct from enabled intent; settings and disabling work',
    (tester) async {
      service.allowed = false;
      service.grantOnRequest = false;
      repository.settings['debt'] = const ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        enabled: true,
      );
      await boot(tester);
      expect(service.requests, 0);
      expect(find.text('ยังไม่ได้รับอนุญาตแจ้งเตือน'), findsOneWidget);
      await tap(tester, find.byTooltip('การแจ้งเตือน'));
      expect(find.text('ยังไม่อนุญาตการแจ้งเตือน'), findsOneWidget);
      expect(find.text('เปิดการแจ้งเตือนในแอปอยู่'), findsOneWidget);
      await tap(tester, find.text('ยังไม่อนุญาตการแจ้งเตือน'));
      expect(service.settingsOpened, 1);
      await tap(tester, find.text('ปิดการแจ้งเตือนทั้งหมด'));
      expect(repository.settings['debt']!.enabled, false);
      expect(repository.settings['debt']!.dueDay, 27);
      expect(service.pending, isEmpty);
      service.allowed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('อนุญาตการแจ้งเตือนแล้ว'), findsOneWidget);
      expect(find.text('ปิดการแจ้งเตือนในแอปอยู่'), findsOneWidget);
    },
  );

  testWidgets(
    'Schedule failure shows retry and recovers without losing saved settings',
    (tester) async {
      repository.settings['debt'] = const ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        enabled: true,
      );
      service.failSchedule = true;
      await boot(tester);
      expect(find.text('จัดตารางแจ้งเตือนไม่สำเร็จ'), findsOneWidget);
      service.failSchedule = false;
      await tap(tester, find.text('ลองจัดตารางใหม่'));
      expect(find.text('จัดตารางแจ้งเตือนไม่สำเร็จ'), findsNothing);
      expect(service.pending, hasLength(48));
    },
  );

  testWidgets('Onboarding and sheet tolerate narrow screens and large text', (
    tester,
  ) async {
    repository.done = false;
    await boot(tester, size: const Size(320, 568), scale: 1.8);
    await tap(tester, find.text('ไว้ทีหลัง'));
    await tap(tester, find.text('ตั้งวันครบกำหนดและแจ้งเตือน'));
    expect(tester.takeException(), isNull);
    await tap(tester, find.byIcon(Icons.close));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notification visual references with bundled fonts', (
    tester,
  ) async {
    final fonts = FontLoader('Kanit')
      ..addFont(rootBundle.load('assets/fonts/Kanit-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    String golden(String name) =>
        'goldens/${Platform.isLinux ? 'linux/' : ''}$name.png';
    repository.done = false;
    await boot(tester);
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('notification_onboarding')),
    );
    await tap(tester, find.text('ไว้ทีหลัง'));
    repository.settings['debt'] = const ReminderSettings(
      debtId: 'debt',
      dueDay: 27,
      enabled: true,
    );
    final context = tester.element(find.byType(NgenBillsApp));
    await ProviderScope.containerOf(context)
        .read(reminderControllerProvider.notifier)
        .refresh();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('reminder_home')),
    );
    await tap(tester, find.text('ครบกำหนดวันที่ 27 ของเดือน'));
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('reminder_sheet')),
    );
    await tap(tester, find.byIcon(Icons.close));
    await tap(tester, find.byTooltip('การแจ้งเตือน'));
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('notification_settings')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Reminder amounts reconcile even if the refreshed Home read fails',
    (tester) async {
      repository.settings['debt'] = const ReminderSettings(
        debtId: 'debt',
        dueDay: 27,
        enabled: true,
      );
      var failHomeRead = false;
      await boot(tester, failHomeRead: () => failHomeRead);
      expect(service.pending.first.body, contains('฿10,000'));
      debts.amountMinor = 700000;
      failHomeRead = true;
      final context = tester.element(find.byType(NgenBillsApp));
      ProviderScope.containerOf(context).invalidate(debtSummaryProvider);
      await tester.pumpAndSettle();
      expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
      expect(service.pending.first.body, contains('฿7,000'));
      expect(tester.takeException(), isNull);
    },
  );
}
