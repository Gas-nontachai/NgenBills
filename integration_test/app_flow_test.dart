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

      Future<void> tap(String text) async {
        final target = find.text(text).last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.ensureVisible(target);
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
        await tester.tap(find.byTooltip('เมนูหนี้'));
        await tester.pumpAndSettle();
        await tap('ปรับแต่งบัญชี');
        await tester.enterText(find.byType(TextFormField), 'รถของเรา');
        await tester.tap(find.byTooltip('รถ'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('ชมพู'));
        await tester.tap(find.byTooltip('ชมพู'));
        await tester.pumpAndSettle();
        await tap('บันทึก');
        await tester.tap(find.byTooltip('เมนูหนี้'));
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
        await tester.tap(find.byTooltip('เมนูหนี้'));
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
        expect(find.text('บัญชีใหม่'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await database.close();
        await deleteDatabase(databasePath);
      }
    },
  );
}
