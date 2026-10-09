import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/payment/presentation/widgets/payment_list_item.dart';
import 'package:ngenbills/features/debt/presentation/widgets/borrowing_list_item.dart';
import 'package:ngenbills/features/debt/presentation/widgets/account_swipe_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native SQLite: payments, customization, borrowing, reopen and account deletion',
    (tester) async {
      final databasePath = path.join(
        await getDatabasesPath(),
        'ngenbills-test-${const Uuid().v4()}.db',
      );
      var database = AppDatabase(databasePath: databasePath);
      Future<void> boot() async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [databaseProvider.overrideWithValue(database)],
            child: const NgenBillsApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> waitForText(String position) async {
        for (var i = 0; i < 50 && find.text(position).evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.text(position), findsWidgets);
      }

      Future<void> waitForPosition(String text) async {
        final target = find.descendant(
          of: find.byKey(const ValueKey('active-account-card')),
          matching: find.text(text),
        );
        for (var i = 0; i < 50 && target.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(target, findsOneWidget);
      }

      Future<void> tap(String text) async {
        await waitForText(text);
        final target = find.text(text).last;
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      }

      Future<void> tapMenu() async {
        await waitForText('ประวัติรายการ');
        final target = find.byTooltip('เมนูหนี้');
        await Scrollable.ensureVisible(tester.element(target), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      try {
        await boot();
        expect(find.text('มาเริ่มจัดการ\nหนี้ก้อนแรกกัน'), findsOneWidget);
        await tap('เพิ่มหนี้ก้อนแรก');
        await tester.enterText(find.byType(TextFormField).at(0), 'บัตรเครดิต');
        await tester.enterText(find.byType(TextFormField).at(1), '10000.50');
        await tap('สร้างหนี้ก้อนแรก');
        expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsOneWidget);
        await tap('ไว้ทีหลัง');
        await tap('ตกลง');
        await tap('บันทึกการจ่าย');
        await tester.enterText(find.byType(TextFormField).first, '3000.50');
        await tester.pumpAndSettle();
        await tap('บันทึกการจ่าย');
        expect(find.text('฿7,000'), findsNWidgets(2));
        expect(find.byType(PaymentListItem), findsOneWidget);
        // Recreate app state and reopen the same on-device SQLite file.
        await tester.pumpWidget(const SizedBox());
        await database.close();
        database = AppDatabase(databasePath: databasePath);
        await boot();
        expect(find.text('฿7,000'), findsNWidgets(2));
        expect(find.byType(PaymentListItem), findsOneWidget);
        await Scrollable.ensureVisible(
          tester.element(find.byType(PaymentListItem)),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PaymentListItem));
        await tester.pumpAndSettle();
        expect(find.text('฿3,000.50'), findsWidgets);
        await tap('ลบรายการจ่าย');
        expect(find.byType(PaymentListItem), findsOneWidget);
        await tap('ลบรายการจ่าย');
        expect(find.byType(PaymentListItem), findsNothing);
        expect(find.text('฿10,000.50'), findsNWidgets(2));
        await tap('บันทึกการจ่าย');
        await tester.enterText(find.byType(TextFormField).first, '10000.50');
        await tester.pumpAndSettle();
        await tap('บันทึกการจ่าย');
        expect(find.text('ชำระครบแล้ว! 🎉'), findsOneWidget);
        expect(find.text('฿0.00'), findsOneWidget);
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
        await tap('ลบรายการจ่าย');
        await tap('ลบรายการจ่าย');
        expect(find.text('บันทึกการจ่าย'), findsOneWidget);
        // Customize and borrow, then reopen the native database and app state.
        await tester.scrollUntilVisible(
          find.byTooltip('เมนูหนี้'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tapMenu();
        await tester.pumpAndSettle();
        await tap('ปรับแต่งบัญชี');
        await tester.enterText(find.byType(TextFormField), 'รถของเรา');
        await tester.tap(find.byTooltip('รถ'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('ชมพู'));
        await tester.tap(find.byTooltip('ชมพู'));
        await tester.pumpAndSettle();
        await tap('บันทึก');
        await tapMenu();
        await tester.pumpAndSettle();
        await tap('กู้เพิ่ม');
        await tester.enterText(find.byType(TextFormField).first, '5000');
        await tester.pumpAndSettle();
        await tap('บันทึกการกู้เพิ่ม');
        expect(find.text('บันทึกการกู้เพิ่มแล้ว'), findsOneWidget);
        await tap('ตกลง');
        await tester.pumpWidget(const SizedBox());
        await database.close();
        database = AppDatabase(databasePath: databasePath);
        await boot();
        final summary = (await DebtRepository(database).load())!;
        expect(summary.debt.name, 'รถของเรา');
        expect(summary.debt.iconKey, 'car');
        expect(summary.debt.colorKey, 'pink');
        expect(summary.remaining, 1500050);
        expect(summary.debt.initialAmountMinor, 1000050);
        expect(find.byType(BorrowingListItem), findsOneWidget);
        await tester.ensureVisible(find.byType(BorrowingListItem));
        await tester.tap(find.byType(BorrowingListItem));
        await tester.pumpAndSettle();
        await tap('ลบรายการกู้เพิ่ม');
        await tap('ลบรายการกู้เพิ่ม');
        expect((await DebtRepository(database).load())!.remaining, 1000050);
        await tester.scrollUntilVisible(
          find.byTooltip('เมนูหนี้'),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tapMenu();
        await tester.pumpAndSettle();
        await tap('ปรับแต่งบัญชี');
        await tap('ลบบัญชีนี้');
        await tap('ลบอย่างถาวร');
        expect(find.text('เพิ่มหนี้ก้อนแรก'), findsOneWidget);
        expect(await DebtRepository(database).load(), isNull);
        await tap('เพิ่มหนี้ก้อนแรก');
        await tester.enterText(find.byType(TextFormField).at(0), 'บัญชีใหม่');
        await tester.enterText(find.byType(TextFormField).at(1), '100');
        await tap('สร้างหนี้ก้อนแรก');
        expect(find.text('ให้เงินบิล\nช่วยเตือนนะ'), findsNothing);
        await waitForText('บัญชีใหม่');
        final firstId = (await DebtRepository(database).list()).single.id;
        await tap('1 / 1');
        await tap('เพิ่มบัญชี');
        await tester.enterText(find.byType(TextFormField).at(0), 'บัญชีที่สอง');
        await tester.enterText(find.byType(TextFormField).at(1), '200');
        await tap('สร้างบัญชีหนี้');
        await waitForText('บัญชีที่สอง');
        await waitForPosition('2 / 2');
        final secondId = (await DebtRepository(database).list()).last.id;
        expect(await DebtRepository(database).defaultId(), firstId);
        await tap('บันทึกการจ่าย');
        await tester.enterText(find.byType(TextFormField).first, '50');
        await tap('บันทึกการจ่าย');
        await waitForText('บันทึกการจ่ายแล้ว อีกก้าวที่ใกล้เป้าหมาย 🌱');
        expect(
          (await DebtRepository(database).load(secondId))!.remaining,
          15000,
        );
        expect(
          (await DebtRepository(database).load(firstId))!.history,
          isEmpty,
        );
        await Scrollable.ensureVisible(
          tester.element(find.byType(AccountSwipeCard)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        final swipeDistance =
            tester.getSize(find.byType(AccountSwipeCard)).width * .8;
        await tester.drag(
          find.byType(AccountSwipeCard),
          Offset(swipeDistance, 0),
        );
        await tester.pumpAndSettle();
        await waitForPosition('1 / 2');
        await waitForText('ประวัติรายการ');
        await tester.drag(
          find.byType(AccountSwipeCard),
          Offset(-swipeDistance, 0),
        );
        await tester.pumpAndSettle();
        await waitForPosition('2 / 2');
        await waitForText('ประวัติรายการ');
        final card = find.byType(AccountSwipeCard);
        Future<TestGesture> revealPlus() async {
          final gesture = await tester.startGesture(tester.getCenter(card));
          await gesture.moveBy(const Offset(-30, 0));
          await gesture.moveBy(const Offset(-140, 0));
          await tester.pump();
          return gesture;
        }

        var held = await revealPlus();
        await tester.pump(const Duration(milliseconds: 300));
        await held.cancel();
        await tester.pumpAndSettle();
        await waitForPosition('2 / 2');
        held = await revealPlus();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('ปล่อยเพื่อเพิ่มบัญชี'), findsOneWidget);
        await held.up();
        await tester.pumpAndSettle();
        await waitForText('สร้างบัญชีหนี้');
        await tester.tap(find.byTooltip('กลับ'));
        await tester.pumpAndSettle();
        await waitForPosition('2 / 2');
        await tap('บัญชีที่สอง');
        await tap('บัญชีใหม่');
        expect(find.text('1 / 2'), findsOneWidget);
        await tester.tap(find.byTooltip('บัญชีถัดไป'));
        await tester.pumpAndSettle();
        await tapMenu();
        await tester.pumpAndSettle();
        await tap('ปรับแต่งบัญชี');
        await tap('ตั้งเป็นบัญชีหลัก');
        expect(await DebtRepository(database).defaultId(), secondId);
        await tester.tap(find.byTooltip('ปิด'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await database.close();
        database = AppDatabase(databasePath: databasePath);
        await boot();
        await waitForText('บัญชีที่สอง');
        expect(find.text('฿150'), findsNWidgets(2));
        await tapMenu();
        await tester.pumpAndSettle();
        await tap('ปรับแต่งบัญชี');
        await tap('ลบบัญชีนี้');
        expect(find.textContaining('จะเป็นบัญชีหลักแทน'), findsOneWidget);
        await tap('ลบอย่างถาวร');
        await waitForText('บัญชีใหม่');
        expect(await DebtRepository(database).defaultId(), firstId);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await database.close();
        await deleteDatabase(databasePath);
      }
    },
  );
}
