import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/app/theme/app_colors.dart';
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
  Future<DebtSummary?> load([String? debtId]) async => DebtSummary(
    Debt(
      id: 'debt',
      name: 'บัตรเครดิต',
      initialAmountMinor: amountMinor,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    [],
  );
  @override
  Future<List<Debt>> list() async => [(await load())!.debt];
  @override
  Future<String?> defaultId() async => 'debt';
  @override
  Future<List<DebtSummary>> loadAll() async => [(await load())!];
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
            debtSummaryByIdProvider.overrideWith((ref, id) async {
              if (failHomeRead()) throw StateError('Home read failed');
              return debts.load(id);
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
    await tester.pumpAndSettle();
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
      expect(find.text('ยินดีด้วย! 🎉'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tap(tester, find.text('ตกลง'));
      expect(repository.done, true);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('ตั้งวันครบกำหนดและแจ้งเตือน'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsNothing);
      expect(find.text('ยินดีด้วย! 🎉'), findsNothing);
      expect(service.requests, 0);
    },
  );

  testWidgets(
    'Onboarding enable requests once and returns home until settings are opened manually',
    (tester) async {
      repository.done = false;
      await boot(tester);
      await tap(tester, find.text('เปิดการแจ้งเตือน'));
      expect(find.text('ยินดีด้วย! 🎉'), findsOneWidget);
      await tap(tester, find.text('ตกลง'));
      expect(service.requests, 1);
      expect(repository.done, true);
      expect(find.byType(ReminderSettingsSheet), findsNothing);
      expect(find.text('ประวัติรายการ'), findsOneWidget);
      expect(repository.settings, isEmpty);
      await tap(tester, find.text('ตั้งวันครบกำหนดและแจ้งเตือน'));
      expect(find.byType(ReminderSettingsSheet), findsOneWidget);
      expect(service.requests, 1);
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
      expect(save.onPressed, isNotNull);
      await tap(tester, find.text('วันที่ 1'));
      await tap(tester, find.text('1'));
      await tap(tester, find.text('ยืนยัน'));
      await tap(tester, find.text('เวลาแจ้งเตือน 09:00 น.'));
      expect(
        tester
            .widget<TimePickerDialog>(find.byType(TimePickerDialog))
            .initialEntryMode,
        TimePickerEntryMode.dial,
      );
      expect(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(
        MediaQuery.of(tester.element(find.byType(TimePickerDialog)))
            .alwaysUse24HourFormat,
        true,
      );
      await tap(tester, find.byIcon(Icons.keyboard_outlined));
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
      await tap(tester, find.text('อีก 24 วัน'));
      expect(find.text('เวลาแจ้งเตือน 14:37 น.'), findsOneWidget);
      await tap(tester, find.text('วันครบกำหนด').last);
      await tap(tester, find.byIcon(Icons.close));
      expect(repository.settings['debt']!.remindOnDueDate, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Multi-select and day picker confirm/cancel preserve committed settings',
    (tester) async {
      await boot(tester);
      await tap(tester, find.byTooltip('เมนูหนี้'));
      await tap(tester, find.text('ตั้งค่าการแจ้งเตือน'));
      await tap(tester, find.text('วันที่ 1'));
      await tap(tester, find.text('31'));
      await tap(tester, find.byIcon(Icons.close).last);
      expect(find.text('วันที่ 1'), findsOneWidget);
      await tap(tester, find.text('วันที่ 1'));
      await tap(tester, find.text('31'));
      await tap(tester, find.text('ยืนยัน'));
      await tap(tester, find.byType(SwitchListTile));
      await tap(tester, find.text('7 วันก่อน'));
      await tap(tester, find.text('1 วันก่อน'));
      await tap(tester, find.text('บันทึกการตั้งค่า'));
      expect(repository.settings['debt']!.advanceDays, {1, 3, 7});
      expect(repository.settings['debt']!.dueDay, 31);
      expect(service.pending, hasLength(60));
      await tap(tester, find.text('อีก 23 วัน'));
      await tap(tester, find.text('7 วันก่อน'));
      await tap(tester, find.byIcon(Icons.close));
      expect(repository.settings['debt']!.advanceDays, {1, 3, 7});
      await tap(tester, find.text('อีก 23 วัน'));
      for (final label in [
        '7 วันก่อน',
        '3 วันก่อน',
        '1 วันก่อน',
        'วันครบกำหนด',
      ]) {
        await tap(tester, find.text(label).last);
      }
      expect(
        find.text('ไม่ได้เลือกวันเตือน จะบันทึกเฉพาะวันครบกำหนด'),
        findsOneWidget,
      );
      await tap(tester, find.text('บันทึกการตั้งค่า'));
      expect(service.pending, isEmpty);
      expect(repository.settings['debt']!.advanceDays, isEmpty);
      expect(find.text('อีก 23 วัน'), findsOneWidget);
    },
  );

  testWidgets(
    'Fresh settings stay disabled until explicitly enabled and preserve denied intent',
    (tester) async {
      service.allowed = false;
      service.grantOnRequest = false;
      await boot(tester);
      await tap(tester, find.text('ตั้งวันครบกำหนดและแจ้งเตือน'));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      expect(find.text('วันที่ 1'), findsOneWidget);
      expect(service.requests, 0);
      expect(repository.settings, isEmpty);
      await tap(tester, find.byType(SwitchListTile));
      await tap(tester, find.text('บันทึกการตั้งค่า'));
      expect(service.requests, 1);
      final saved = repository.settings['debt']!;
      expect(saved.enabled, true);
      expect(saved.dueDay, 1);
      expect(saved.advanceDays, {3});
      expect(saved.remindOnDueDate, true);
      expect(saved.hour, 9);
      expect(saved.minute, 0);
      expect(service.pending, isEmpty);
      await tap(tester, find.text('อีก 24 วัน'));
      await tap(tester, find.byType(SwitchListTile));
      await tap(tester, find.text('บันทึกการตั้งค่า'));
      expect(service.requests, 1);
      await tap(tester, find.text('อีก 24 วัน'));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
    },
  );

  for (final (days, color) in [
    (0, AppColors.dueUrgent),
    (3, AppColors.dueUrgent),
    (4, AppColors.dueSoon),
    (7, AppColors.dueSoon),
    (8, AppColors.text),
  ]) {
    testWidgets(
      'Countdown urgency at $days days works with notifications disabled',
      (tester) async {
        repository.settings['debt'] = ReminderSettings(
          debtId: 'debt',
          dueDay: 8 + days,
        );
        await boot(tester);
        final counter = find.text(days == 0 ? 'วันนี้' : 'อีก $days วัน');
        expect(counter, findsOneWidget);
        expect(tester.widget<Text>(counter).style!.color, color);
        expect(find.text('ปิดการแจ้งเตือนอยู่'), findsOneWidget);
        expect(service.pending, isEmpty);
      },
    );
  }

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
      await tap(tester, find.byTooltip('ตั้งค่า'));
      await tap(tester, find.text('การแจ้งเตือน').last);
      expect(find.text('ยังไม่อนุญาตการแจ้งเตือน'), findsOneWidget);
      expect(find.text('เปิดเตือน · ครบกำหนดวันที่ 27'), findsOneWidget);
      await tap(tester, find.text('ยังไม่อนุญาตการแจ้งเตือน'));
      expect(service.settingsOpened, 1);
      await tap(tester, find.text('ปิดการแจ้งเตือนทั้งหมด'));
      expect(repository.settings['debt']!.enabled, true);
      await tap(tester, find.text('ยกเลิก'));
      expect(repository.settings['debt']!.enabled, true);
      await tap(tester, find.text('ปิดการแจ้งเตือนทั้งหมด'));
      await tap(tester, find.text('ยืนยันปิดการแจ้งเตือนทั้งหมด'));
      expect(repository.settings['debt']!.enabled, false);
      expect(repository.settings['debt']!.dueDay, 27);
      expect(service.pending, isEmpty);
      service.allowed = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('อนุญาตการแจ้งเตือนแล้ว'), findsOneWidget);
      expect(find.text('ปิดเตือนอยู่'), findsOneWidget);
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
    await tap(tester, find.text('ตกลง'));
    await tap(tester, find.text('ตั้งวันครบกำหนดและแจ้งเตือน'));
    expect(tester.takeException(), isNull);
    await tap(tester, find.text('วันที่ 1'));
    await tap(tester, find.text('31'));
    await tap(tester, find.text('ยืนยัน'));
    expect(find.text('วันที่ 31'), findsOneWidget);
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
    await tap(tester, find.text('ตกลง'));
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
    await tap(tester, find.text('อีก 19 วัน'));
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('reminder_sheet')),
    );
    await tap(tester, find.text('วันที่ 27'));
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('due_day_sheet')),
    );
    await tap(tester, find.byIcon(Icons.close).last);
    await tap(tester, find.byIcon(Icons.close));
    await tap(tester, find.byTooltip('ตั้งค่า'));
    await tap(tester, find.text('การแจ้งเตือน').last);
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
      final container = ProviderScope.containerOf(context);
      container.invalidate(debtSummaryByIdProvider('debt'));
      container.invalidate(accountsProvider);
      await tester.pumpAndSettle();
      expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
      expect(service.pending.first.body, contains('฿7,000'));
      expect(tester.takeException(), isNull);
    },
  );
}
