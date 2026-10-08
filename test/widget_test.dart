import 'dart:io';

import 'support/reminder_fakes.dart';

import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/app/theme/app_theme.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/core/widgets/buttons/app_button.dart';
import 'package:ngenbills/core/widgets/inputs/app_amount_field.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/debt/presentation/widgets/half_donut_chart.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/payment/domain/entities/payment.dart';
import 'package:ngenbills/features/payment/presentation/widgets/payment_list_item.dart';

class Store {
  Debt? debt;
  final payments = <Payment>[];
  int writes = 0;
  DebtSummary? get summary =>
      debt == null ? null : DebtSummary(debt!, List.of(payments.reversed));
  void seed({int paid = 0}) {
    final date = DateTime(2026, 10, 1);
    debt = Debt(
      id: 'debt',
      name: 'บัตรเครดิต',
      initialAmountMinor: 1000000,
      createdAt: date,
      updatedAt: date,
    );
    if (paid > 0) {
      payments.add(
        Payment(
          id: 'payment',
          debtId: 'debt',
          amountMinor: paid,
          date: date,
          createdAt: date,
        ),
      );
    }
  }
}

class TestDebts extends DebtRepository {
  TestDebts(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final Store store;
  @override
  Future<DebtSummary?> load() async => store.summary;
  @override
  Future<void> create({
    required String name,
    required int amountMinor,
    String? note,
  }) async {
    store.writes++;
    final now = DateTime.now();
    store.debt = Debt(
      id: 'debt',
      name: name.trim(),
      initialAmountMinor: amountMinor,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class TestPayments extends PaymentRepository {
  TestPayments(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final Store store;
  @override
  Future<void> add({
    required String debtId,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) async {
    store.writes++;
    store.payments.add(
      Payment(
        id: 'p${store.writes}',
        debtId: debtId,
        amountMinor: amountMinor,
        date: date,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<bool> delete(String id) async {
    store.payments.removeWhere((p) => p.id == id);
    return true;
  }
}

void main() {
  Future<void> boot(
    WidgetTester tester,
    Store store, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool onboardingDone = true,
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
          reminderRepositoryProvider.overrideWithValue(
            MemoryReminderRepository(done: onboardingDone),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          debtRepositoryProvider.overrideWithValue(TestDebts(store)),
          paymentRepositoryProvider.overrideWithValue(TestPayments(store)),
        ],
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('AppButton supports disabled and loading states', (tester) async {
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: AppButton(
            label: 'save',
            onPressed: () => count++,
            isLoading: true,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    expect(count, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'save', onPressed: () => count++),
        ),
      ),
    );
    await tester.tap(find.text('save'));
    expect(count, 1);
  });
  testWidgets('Amount input accepts satang and rejects extra decimals', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: Form(
            child: AppAmountField(controller: controller, remaining: 10000),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '10.50');
    expect(controller.text, '10.50');
    await tester.enterText(find.byType(TextFormField), '10.501');
    expect(controller.text, '10.50');
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.pump();
    expect(find.textContaining('เกินยอดคงเหลือ'), findsOneWidget);
  });
  testWidgets('Half donut handles endpoints and provides accessible progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final progress in [0.0, .3, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: HalfDonutChart(
                progress: progress,
                center: const Text('balance'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          RegExp('ชำระแล้ว ${(progress * 100).round()} เปอร์เซ็นต์'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });
  testWidgets(
    'Notification onboarding follows successful first debt creation',
    (tester) async {
      final store = Store();
      await boot(tester, store, onboardingDone: false);
      expect(find.text('มาเริ่มจัดการ\nหนี้ก้อนแรกกัน'), findsOneWidget);
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsNothing);
      await tap(tester, 'เพิ่มหนี้ก้อนแรก');
      await tap(tester, 'สร้างหนี้ก้อนแรก');
      expect(find.text('กรุณากรอกชื่อหนี้'), findsOneWidget);
      expect(store.debt, isNull);
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), 'บัตรเครดิต');
      await tester.enterText(find.byType(TextFormField).at(1), '10000');
      await tap(tester, 'สร้างหนี้ก้อนแรก');
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsOneWidget);
      expect(store.debt!.initialAmountMinor, 1000000);
      await tap(tester, 'ไว้ทีหลัง');
      expect(find.text('บัตรเครดิต'), findsOneWidget);
      expect(find.text('ยังไม่มีประวัติการจ่าย'), findsOneWidget);
      expect(store.debt!.initialAmountMinor, 1000000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsNothing);
    },
  );
  testWidgets('Payment save, details, explicit deletion and recalculation', (
    tester,
  ) async {
    final store = Store()..seed();
    await boot(tester, store);
    await tap(tester, 'บันทึกการจ่าย');
    await tester.enterText(find.byType(TextFormField).first, '3000');
    await tester.pumpAndSettle();
    await tap(tester, 'บันทึกการจ่าย');
    expect(store.payments.length, 1);
    expect(find.text('ชำระแล้ว 30%'), findsOneWidget);
    expect(find.text('฿7,000'), findsNWidgets(2));
    await tester.tap(find.byType(PaymentListItem));
    await tester.pumpAndSettle();
    expect(find.text('รายละเอียดการจ่าย'), findsOneWidget);
    await tap(tester, 'ลบรายการจ่าย');
    expect(store.payments.length, 1);
    expect(find.textContaining('ยอดคงเหลือจะถูกคำนวณใหม่'), findsOneWidget);
    await tap(tester, 'ยกเลิก');
    expect(store.payments.length, 1);
    await tester.tap(find.byType(PaymentListItem));
    await tester.pumpAndSettle();
    await tap(tester, 'ลบรายการจ่าย');
    await tap(tester, 'ลบรายการจ่าย');
    expect(store.payments, isEmpty);
    expect(find.text('ชำระแล้ว 0%'), findsOneWidget);
  });
  testWidgets('Unsaved sheet back/outside asks and cancel preserves input', (
    tester,
  ) async {
    final store = Store()..seed();
    await boot(tester, store);
    await tap(tester, 'บันทึกการจ่าย');
    await tester.enterText(find.byType(TextFormField).first, '500');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('ละทิ้งข้อมูลที่กรอกไว้?'), findsOneWidget);
    await tap(tester, 'ยกเลิก');
    expect(find.text('500'), findsOneWidget);
    // Tapping the modal barrier must follow the same guarded dismissal path.
    await tester.tapAt(const Offset(10, 70));
    await tester.pumpAndSettle();
    expect(find.text('ละทิ้งข้อมูลที่กรอกไว้?'), findsOneWidget);
    await tap(tester, 'ละทิ้งข้อมูล');
    expect(find.byType(TextFormField), findsNothing);
    expect(store.payments, isEmpty);
  });
  testWidgets('Unchanged sheet dismisses by tapping outside', (tester) async {
    await boot(tester, Store()..seed());
    await tap(tester, 'บันทึกการจ่าย');
    await tester.tapAt(const Offset(10, 70));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('Fully paid disables payment and deleting restores it', (
    tester,
  ) async {
    final store = Store()..seed(paid: 1000000);
    await boot(tester, store);
    expect(find.text('ชำระครบแล้ว! 🎉'), findsOneWidget);
    expect(find.text('฿0.00'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNull);
    await tester.scrollUntilVisible(
      find.byType(PaymentListItem),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byType(PaymentListItem)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PaymentListItem));
    await tester.pumpAndSettle();
    await tap(tester, 'ลบรายการจ่าย');
    await tap(tester, 'ลบรายการจ่าย');
    expect(find.text('บันทึกการจ่าย'), findsOneWidget);
  });
  testWidgets('Small phone, large text and keyboard avoid overflow', (
    tester,
  ) async {
    await boot(
      tester,
      Store()..seed(paid: 300000),
      size: const Size(320, 568),
      scale: 1.8,
    );
    expect(tester.takeException(), isNull);
    await tap(tester, 'บันทึกการจ่าย');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '500');
    await tap(tester, 'บันทึกการจ่าย');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Error state retries and recovers into empty home', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(
            MemoryReminderRepository(),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          debtRepositoryProvider.overrideWithValue(TestDebts(Store())),
          debtSummaryProvider.overrideWith((ref) async {
            if (attempts++ == 0) throw StateError('read failed');
            return null;
          }),
        ],
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
    await tap(tester, 'ลองอีกครั้ง');
    expect(find.text('เพิ่มหนี้ก้อนแรก'), findsOneWidget);
  });
  testWidgets('Date picker limits future dates and optional note is saved', (
    tester,
  ) async {
    final store = Store()..seed();
    await boot(tester, store);
    await tap(tester, 'บันทึกการจ่าย');
    await tester.tap(find.byIcon(Icons.calendar_today_outlined).last);
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final now = DateTime.now();
    expect(picker.lastDate, DateTime(now.year, now.month, now.day));
    await tap(tester, 'ยืนยัน');
    await tap(tester, 'เพิ่มหมายเหตุ (ไม่บังคับ)');
    await tester.enterText(find.byType(TextFormField).last, 'จ่ายผ่านธนาคาร');
    await tester.enterText(find.byType(TextFormField).first, '0.01');
    await tester.pumpAndSettle();
    await tap(tester, 'บันทึกการจ่าย');
    expect(store.payments.single.amountMinor, 1);
    expect(store.payments.single.note, 'จ่ายผ่านธนาคาร');
  });
  testWidgets('Visual reference snapshots with bundled Kanit', (tester) async {
    // Font rasterization differs between macOS and Linux. Keep exact pixel
    // comparisons against a reviewed baseline from the same host renderer.
    String golden(String name) =>
        'goldens/${Platform.isLinux ? 'linux/' : ''}$name.png';
    final fonts = FontLoader('Kanit');
    fonts.addFont(rootBundle.load('assets/fonts/Kanit-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final store = Store();
    await boot(tester, store);
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('empty_home')),
    );
    await tap(tester, 'เพิ่มหนี้ก้อนแรก');
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('create_debt')),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'บัตรเครดิต');
    await tester.enterText(find.byType(TextFormField).at(1), '10000');
    await tap(tester, 'สร้างหนี้ก้อนแรก');
    await tap(tester, 'บันทึกการจ่าย');
    await tester.enterText(find.byType(TextFormField).first, '3000');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('add_payment')),
    );
    await tap(tester, 'บันทึกการจ่าย');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('debt_home')),
    );
    await tester.tap(find.byType(PaymentListItem));
    await tester.pumpAndSettle();
    await tap(tester, 'ลบรายการจ่าย');
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('delete_payment')),
    );
    await tap(tester, 'ยกเลิก');
    await tap(tester, 'บันทึกการจ่าย');
    await tester.enterText(find.byType(TextFormField).first, '7000');
    await tester.pumpAndSettle();
    await tap(tester, 'บันทึกการจ่าย');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('fully_paid')),
    );
  });
}
