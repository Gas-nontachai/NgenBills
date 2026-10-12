import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/app/theme/app_theme.dart';
import 'package:ngenbills/features/payment/domain/entities/payment.dart';
import 'package:ngenbills/features/payment/presentation/widgets/payment_detail_sheet.dart';
import 'package:ngenbills/features/debt/domain/entities/borrowing.dart';
import 'package:ngenbills/features/debt/presentation/sheets/borrowing_detail_sheet.dart';

void main() {
  Future<void> showDetail(
    WidgetTester tester,
    Widget detail, {
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
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => detail,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  final date = DateTime(2026, 10, 1);
  for (final payment in [true, false]) {
    final name = payment ? 'payment_detail' : 'borrowing_detail';
    Widget detail({bool long = false}) => payment
        ? PaymentDetailSheet(
            payment: Payment(
              id: 'p',
              debtId: 'd',
              amountMinor: long ? 99999999999999 : 60000,
              date: date,
              createdAt: date,
              isEdited: true,
              note: long ? 'note ' * 100 : null,
            ),
          )
        : BorrowingDetailSheet(
            borrowing: Borrowing(
              id: 'b',
              debtId: 'd',
              amountMinor: long ? 99999999999999 : 125000,
              date: date,
              createdAt: date,
              isEdited: true,
              note: long ? 'note ' * 100 : 'For repairs',
            ),
          );
    testWidgets('$name stacks actions for small screen and large text', (
      tester,
    ) async {
      await showDetail(tester, detail(long: true), small: true);
      final edit = find.text('แก้ไขรายการ');
      final delete = find.text(payment ? 'ลบรายการจ่าย' : 'ลบรายการกู้เพิ่ม');
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(delete).dy,
        greaterThan(tester.getTopLeft(edit).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
