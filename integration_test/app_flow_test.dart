import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/payment/presentation/widgets/payment_list_item.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native SQLite: create, pay, reopen, delete, fully pay and restore',
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
        await tester.ensureVisible(find.byType(PaymentListItem));
        await tester.tap(find.byType(PaymentListItem));
        await tester.pumpAndSettle();
        await tap('ลบรายการจ่าย');
        await tap('ลบรายการจ่าย');
        expect(find.text('บันทึกการจ่าย'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await database.close();
        await deleteDatabase(databasePath);
      }
    },
  );
}
