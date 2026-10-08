import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/data/repositories/borrowing_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/entities/borrowing.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/debt/presentation/widgets/borrowing_list_item.dart';
import 'package:ngenbills/features/debt/presentation/widgets/account_avatar.dart';
import 'package:ngenbills/features/debt/presentation/sheets/add_borrowing_sheet.dart';
import 'package:ngenbills/features/debt/presentation/sheets/customize_account_sheet.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';

import 'support/reminder_fakes.dart';

class _Store {
  Debt? debt = Debt(
    id: 'debt',
    name: 'จ่ายไปเรื่อย',
    initialAmountMinor: 13000000,
    note: 'หมายเหตุเดิม',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final borrowings = <Borrowing>[];
  bool fail = false;
  Completer<void>? pending;
  int writes = 0;
  DebtSummary? get summary =>
      debt == null ? null : DebtSummary(debt!, [], List.of(borrowings));
}

class _Debts extends DebtRepository {
  _Debts(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final _Store store;
  @override
  Future<DebtSummary?> load() async => store.summary;
  @override
  Future<void> customize({
    required String debtId,
    required String name,
    required String iconKey,
    required String colorKey,
  }) async {
    store.writes++;
    await store.pending?.future;
    if (store.fail) throw StateError('write failed');
    final old = store.debt!;
    store.debt = Debt(
      id: old.id,
      name: name.trim(),
      initialAmountMinor: old.initialAmountMinor,
      note: old.note,
      iconKey: iconKey,
      colorKey: colorKey,
      createdAt: old.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<bool> delete(String debtId) async {
    store.writes++;
    await store.pending?.future;
    if (store.fail) throw StateError('write failed');
    store.debt = null;
    store.borrowings.clear();
    return true;
  }
}

class _Borrowings extends BorrowingRepository {
  _Borrowings(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final _Store store;
  @override
  Future<BorrowingReceipt> add({
    required String debtId,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) async {
    store.writes++;
    await store.pending?.future;
    if (store.fail) throw StateError('write failed');
    final remaining = store.summary!.remaining;
    store.borrowings.add(
      Borrowing(
        id: 'b${store.writes}',
        debtId: debtId,
        amountMinor: amountMinor,
        date: date,
        note: note,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return BorrowingReceipt(
      amountMinor: amountMinor,
      previousRemaining: remaining,
    );
  }

  @override
  Future<bool> delete(String id) async {
    store.borrowings.removeWhere((b) => b.id == id);
    return true;
  }
}

class _FailedReminders extends MemoryReminderRepository {
  @override
  Future<bool> onboardingDone() async => throw StateError('read failed');
}

void main() {
  late _Store store;
  setUp(() => store = _Store());
  Future<void> boot(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    MemoryReminderRepository? reminders,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debtClockProvider.overrideWithValue(() => DateTime(2026, 10, 8)),
          debtRepositoryProvider.overrideWithValue(_Debts(store)),
          borrowingRepositoryProvider.overrideWithValue(_Borrowings(store)),
          reminderRepositoryProvider.overrideWithValue(
            reminders ?? MemoryReminderRepository(),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('เมนูหนี้'));
    await tester.pumpAndSettle();
    await tap(tester, label);
  }

  testWidgets('Customize previews, validates, confirms discard and persists', (
    tester,
  ) async {
    await boot(tester);
    await menu(tester, 'ปรับแต่งบัญชี');
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pumpAndSettle();
    expect(find.text('กรุณากรอกชื่อบัญชี'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'รถของเรา');
    await tester.tap(find.byTooltip('รถ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('ชมพู'));
    await tester.tap(find.byTooltip('ชมพู'));
    await tester.pumpAndSettle();
    final preview = tester.widget<AccountAvatar>(
      find.descendant(
        of: find.byType(CustomizeAccountSheet),
        matching: find.byType(AccountAvatar),
      ),
    );
    expect(preview.iconKey, 'car');
    expect(preview.colorKey, 'pink');
    await tester.ensureVisible(find.byTooltip('ปิด'));
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    expect(find.text('ละทิ้งข้อมูลที่กรอกไว้?'), findsOneWidget);
    await tap(tester, 'ยกเลิก');
    await tap(tester, 'บันทึก');
    expect(store.debt!.name, 'รถของเรา');
    expect(store.debt!.iconKey, 'car');
    expect(store.debt!.colorKey, 'pink');
    expect(store.debt!.note, 'หมายเหตุเดิม');
    await menu(tester, 'ปรับแต่งบัญชี');
    await tester.enterText(find.byType(TextFormField), 'ยังไม่บันทึก');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('ละทิ้งข้อมูลที่กรอกไว้?'), findsOneWidget);
    await tap(tester, 'ละทิ้งข้อมูล');
    expect(store.debt!.name, 'รถของเรา');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Borrowing success reports committed balances and history can delete',
    (tester) async {
      await boot(tester);
      await menu(tester, 'กู้เพิ่ม');
      await tester.enterText(find.byType(TextFormField).first, '5000');
      await tester.enterText(find.byType(TextFormField).last, 'ซ่อมรถ');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calendar_today_outlined).last);
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, DateTime(2026, 10, 8));
      await tap(tester, 'ยืนยัน');
      await tap(tester, 'บันทึกการกู้เพิ่ม');
      expect(find.text('บันทึกการกู้เพิ่มแล้ว'), findsOneWidget);
      expect(find.text('฿135,000'), findsWidgets);
      expect(find.text('จากเดิม ฿130,000'), findsOneWidget);
      expect(store.borrowings.single.note, 'ซ่อมรถ');
      await tap(tester, 'ตกลง');
      expect(find.text('จากยอดหนี้รวม ฿135,000'), findsOneWidget);
      await tester.ensureVisible(find.byType(BorrowingListItem));
      await tester.tap(find.byType(BorrowingListItem));
      await tester.pumpAndSettle();
      expect(find.text('รายละเอียดการกู้เพิ่ม'), findsOneWidget);
      await tap(tester, 'ลบรายการกู้เพิ่ม');
      await tap(tester, 'ยกเลิก');
      expect(store.borrowings, hasLength(1));
      await tester.ensureVisible(find.byType(BorrowingListItem));
      await tester.tap(find.byType(BorrowingListItem));
      await tester.pumpAndSettle();
      await tap(tester, 'ลบรายการกู้เพิ่ม');
      await tap(tester, 'ลบรายการกู้เพิ่ม');
      expect(store.borrowings, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Borrowing failures preserve input, retry and shared lock prevent duplicates',
    (tester) async {
      await boot(tester);
      await menu(tester, 'กู้เพิ่ม');
      await tester.enterText(find.byType(TextFormField).first, '500');
      await tester.pumpAndSettle();
      store.fail = true;
      await tap(tester, 'บันทึกการกู้เพิ่ม');
      expect(find.byType(AddBorrowingSheet), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(store.borrowings, isEmpty);
      store.fail = false;
      store.pending = Completer<void>();
      await tester.ensureVisible(find.text('บันทึกการกู้เพิ่ม'));
      await tester.tap(find.text('บันทึกการกู้เพิ่ม'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AddBorrowingSheet),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AddBorrowingSheet), findsOneWidget);
      expect(store.writes, 2);
      store.pending!.complete();
      await tester.pumpAndSettle();
      expect(store.borrowings, hasLength(1));
      expect(find.text('บันทึกการกู้เพิ่มแล้ว'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Deleting account cancels or commits and leaves empty home', (
    tester,
  ) async {
    await boot(tester);
    await menu(tester, 'ปรับแต่งบัญชี');
    await tap(tester, 'ลบบัญชีนี้');
    expect(find.text('ลบบัญชีนี้?'), findsOneWidget);
    await tap(tester, 'ยกเลิก');
    expect(store.debt, isNotNull);
    await tap(tester, 'ลบบัญชีนี้');
    store.fail = true;
    await tap(tester, 'ลบอย่างถาวร');
    expect(store.debt, isNotNull);
    expect(find.text('ลบบัญชีนี้?'), findsOneWidget);
    store.fail = false;
    await tap(tester, 'ลบอย่างถาวร');
    expect(store.debt, isNull);
    expect(find.text('เพิ่มหนี้ก้อนแรก'), findsOneWidget);
    expect(find.byType(CustomizeAccountSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Reminder load failure does not disable account menu actions', (
    tester,
  ) async {
    // Retain a known completed onboarding value when subsequent reminder reads fail.
    final reminders = MemoryReminderRepository();
    await boot(tester, reminders: reminders);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NgenBillsApp)),
    );
    container.updateOverrides([
      debtClockProvider.overrideWithValue(() => DateTime(2026, 10, 8)),
      debtRepositoryProvider.overrideWithValue(_Debts(store)),
      borrowingRepositoryProvider.overrideWithValue(_Borrowings(store)),
      reminderRepositoryProvider.overrideWithValue(_FailedReminders()),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    ]);
    await container.read(reminderControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('เมนูหนี้'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.ancestor(
              of: find.text('ตั้งค่าการแจ้งเตือน'),
              matching: find.byType(PopupMenuItem<String>),
            ),
          )
          .enabled,
      false,
    );
    await tap(tester, 'กู้เพิ่ม');
    expect(find.byType(AddBorrowingSheet), findsOneWidget);
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    await menu(tester, 'ปรับแต่งบัญชี');
    expect(find.byType(CustomizeAccountSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Initial reminder read failure still allows account customization',
    (tester) async {
      await boot(tester, reminders: _FailedReminders());
      await menu(tester, 'ปรับแต่งบัญชี');
      expect(find.byType(CustomizeAccountSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('New sheets fit small phones, large text and keyboard', (
    tester,
  ) async {
    await boot(tester, size: const Size(320, 568), scale: 1.8);
    await menu(tester, 'ปรับแต่งบัญชี');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ใหม่');
    await tap(tester, 'บันทึก');
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await menu(tester, 'กู้เพิ่ม');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '500');
    await tap(tester, 'บันทึกการกู้เพิ่ม');
    expect(tester.takeException(), isNull);
    await tap(tester, 'ตกลง');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('เมนูหนี้'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await menu(tester, 'ปรับแต่งบัญชี');
    await tap(tester, 'ลบบัญชีนี้');
    expect(find.text('ไม่สามารถกู้คืนข้อมูลได้'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, 'ยกเลิก');
    expect(store.debt, isNotNull);
  });
  testWidgets('Account and borrowing visual references', (tester) async {
    final fonts = FontLoader('Kanit')
      ..addFont(rootBundle.load('assets/fonts/Kanit-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    String golden(String name) =>
        'goldens/${Platform.isLinux ? 'linux/' : ''}$name.png';
    await boot(tester);
    await menu(tester, 'ปรับแต่งบัญชี');
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('customize_account')),
    );
    await tap(tester, 'ลบบัญชีนี้');
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('delete_account')),
    );
    await tap(tester, 'ยกเลิก');
    await tester.tap(find.byTooltip('ปิด'));
    await tester.pumpAndSettle();
    await menu(tester, 'กู้เพิ่ม');
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('add_borrowing')),
    );
    await tap(tester, 'บันทึกการกู้เพิ่ม');
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('borrowing_success')),
    );
    await tap(tester, 'ตกลง');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(golden('borrowing_home')),
    );
    expect(tester.takeException(), isNull);
  });
}
