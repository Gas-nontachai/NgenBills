import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/presentation/widgets/borrowing_list_item.dart';
import 'package:ngenbills/features/debt/domain/services/debt_wording.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/debt/presentation/widgets/debt_progress_card.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/payment/presentation/widgets/payment_list_item.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';

import 'support/reminder_fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase database;
  late DebtRepository debts;
  late String payableId, receivableId;
  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    debts = DebtRepository(database);
    payableId = await debts.create(name: 'บัญชีจ่าย', amountMinor: 100000);
    receivableId = await debts.create(
      name: 'ให้ยืมเพื่อน',
      amountMinor: 100000,
      direction: DebtDirection.receivable,
    );
    await debts.setDefault(receivableId);
  });
  tearDown(() => database.close());

  Future<ProviderContainer> boot(
    WidgetTester tester, {
    bool onboarding = false,
    bool small = false,
  }) async {
    tester.view.physicalSize = small
        ? const Size(320, 568)
        : const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = small ? 1.8 : 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          reminderRepositoryProvider.overrideWithValue(
            MemoryReminderRepository(done: !onboarding),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NgenBillsApp)),
    );
    await container.read(reminderControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.last);
    await tester.pumpAndSettle();
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Receivable return and lending flows save, edit and delete with owner wording',
    (tester) async {
      await tester.runAsync(() async {
        final container = await boot(tester);
        expect(find.text('รับคืนแล้ว'), findsOneWidget);
        expect(find.text('รอรับคืน'), findsOneWidget);
        await tap(tester, find.text('บันทึกการรับคืน'));
        expect(find.text('วันที่รับคืน'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, '200');
        await tap(tester, find.text('บันทึกการรับคืน'));
        expect(find.text('บันทึกการรับคืนแล้ว 🌱'), findsOneWidget);
        expect((await debts.load(receivableId))!.remaining, 80000);
        expect(find.text('รับคืนแล้ว 20%'), findsOneWidget);
        await tap(tester, find.byType(PaymentListItem));
        expect(find.text('รายละเอียดการรับคืน'), findsOneWidget);
        await tap(tester, find.text('แก้ไขรายการ'));
        expect(find.text('แก้ไขรายการรับคืน'), findsOneWidget);
        // The owner remains receivable even when another account is selected.
        container.read(selectedDebtIdProvider.notifier).select(payableId);
        await tester.pumpAndSettle();
        expect(find.text('วันที่รับคืน'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, '300');
        await tap(tester, find.text('บันทึกการแก้ไข'));
        expect((await debts.load(receivableId))!.remaining, 70000);
        expect((await debts.load(payableId))!.remaining, 100000);
        container.read(selectedDebtIdProvider.notifier).select(receivableId);
        await tester.pumpAndSettle();
        await tap(tester, find.byType(PaymentListItem));
        await tap(tester, find.text('ลบรายการรับคืน'));
        expect(find.textContaining('ยอดรอรับคืนจะเพิ่มขึ้น'), findsOneWidget);
        await tap(tester, find.text('ลบรายการรับคืน'));
        expect((await debts.load(receivableId))!.payments, isEmpty);
        await tester.drag(find.byType(ListView).first, const Offset(0, 800));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('เมนูบัญชีให้ยืม'));
        await tester.pumpAndSettle();
        await tap(tester, find.text('ให้ยืมเพิ่ม'));
        expect(find.text('จำนวนเงินที่ให้ยืมเพิ่ม (บาท)'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, '100');
        await tap(tester, find.text('บันทึกการให้ยืมเพิ่ม'));
        expect(find.text('บันทึกการให้ยืมเพิ่มแล้ว'), findsOneWidget);
        await tap(tester, find.text('ตกลง'));
        expect((await debts.load(receivableId))!.remaining, 110000);
        await tap(tester, find.byType(BorrowingListItem));
        expect(find.text('รายละเอียดการให้ยืมเพิ่ม'), findsOneWidget);
        await tap(tester, find.text('แก้ไขรายการ'));
        expect(find.text('แก้ไขรายการให้ยืมเพิ่ม'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, '200');
        await tap(tester, find.text('บันทึกการแก้ไข'));
        expect((await debts.load(receivableId))!.remaining, 120000);
        await tap(tester, find.byType(BorrowingListItem));
        await tap(tester, find.text('ลบรายการให้ยืมเพิ่ม'));
        await tap(tester, find.text('ลบรายการให้ยืมเพิ่ม'));
        expect((await debts.load(receivableId))!.borrowings, isEmpty);
        expect((await debts.load(receivableId))!.remaining, 100000);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'Receivable completed dashboard and accessibility fit large text',
    (tester) async {
      await tester.runAsync(() async {
        await PaymentRepository(database).add(
          debtId: receivableId,
          amountMinor: 100000,
          date: DateTime(2026, 1, 1),
        );
        await boot(tester, small: true);
        final semantics = tester.ensureSemantics();
        expect(find.text('ได้รับเงินคืนครบแล้ว! 🎉'), findsOneWidget);
        expect(find.text('ได้รับเงินคืนครบแล้ว 🌱'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('รับคืนแล้ว 100 เปอร์เซ็นต์')),
          findsOneWidget,
        );
        expect(find.text('เก่งมากเลย! 🌱'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('active-account-card')),
            matching: find.text('ตั้งวันครบกำหนดและแจ้งเตือน'),
          ),
          findsNothing,
        );
        await tester.tap(find.byTooltip('เมนูบัญชีให้ยืม'));
        await tester.pumpAndSettle();
        expect(find.text('ตั้งค่าการแจ้งเตือน'), findsNothing);
        semantics.dispose();
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'Receivable onboarding captures direction before completing gate',
    (tester) async {
      await tester.runAsync(() async {
        await boot(tester, onboarding: true);
        expect(find.text('ไม่พลาดวันรับเงินคืน'), findsOneWidget);
        await tap(tester, find.text('ไว้ทีหลัง'));
        expect(
          find.textContaining('คุณเริ่มต้นติดตามเงินให้ยืมบัญชีแรกแล้ว'),
          findsOneWidget,
        );
        await tap(tester, find.text('ตกลง'));
        expect(find.byType(DebtProgressCard), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'Receivable due date settings keep receive wording through the day picker',
    (tester) async {
      await tester.runAsync(() async {
        await boot(tester);
        await tester.tap(find.byTooltip('เมนูบัญชีให้ยืม'));
        await tester.pumpAndSettle();
        await tap(tester, find.text('ตั้งค่าการแจ้งเตือน'));
        expect(find.text('วันครบกำหนดรับคืน:'), findsOneWidget);
        await tap(tester, find.text('วันที่ 1'));
        expect(find.text('วันครบกำหนดรับคืน'), findsOneWidget);
        await tap(tester, find.text('10'));
        await tap(tester, find.text('ยืนยัน'));
        expect(find.text('วันที่ 10'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'Receivable repository errors retain input and retry uses receive wording',
    (tester) async {
      await tester.runAsync(() async {
        await boot(tester);
        await tap(tester, find.text('บันทึกการรับคืน'));
        final db = await database.instance;
        await db.execute(
          "CREATE TRIGGER fail_receive BEFORE INSERT ON payments BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
        );
        await tester.enterText(find.byType(TextFormField).first, '100');
        await tap(tester, find.text('บันทึกการรับคืน'));
        expect(find.text('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง'), findsOneWidget);
        expect(find.text('100'), findsOneWidget);
        expect((await debts.load(receivableId))!.payments, isEmpty);
        await db.execute('DROP TRIGGER fail_receive');
        await tap(tester, find.text('บันทึกการรับคืน'));
        expect(find.text('บันทึกการรับคืนแล้ว 🌱'), findsOneWidget);
        expect((await debts.load(receivableId))!.payments, hasLength(1));
      });
    },
  );
}
