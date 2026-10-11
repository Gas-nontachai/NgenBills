import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/app/theme/app_theme.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/core/widgets/buttons/app_button.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/data/repositories/borrowing_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/entities/borrowing.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/debt/presentation/widgets/borrowing_list_item.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/payment/domain/entities/payment.dart';
import 'package:ngenbills/features/payment/presentation/widgets/payment_list_item.dart';

class _Store {
  final bool payment;
  _Store(this.payment);
  int amount = 10000, writes = 0;
  String note = 'original';
  DateTime date = DateTime(2020, 1, 1);
  bool edited = false, fail = false, missing = false;
  Completer<void>? pending;
  DebtSummary get summary => DebtSummary(
    Debt(
      id: 'debt',
      name: 'Account',
      initialAmountMinor: 100000,
      createdAt: date,
      updatedAt: date,
    ),
    [
      if (payment && !missing)
        Payment(
          id: 'entry',
          debtId: 'debt',
          amountMinor: amount,
          date: date,
          note: note,
          createdAt: DateTime(2020),
          isEdited: edited,
        ),
    ],
    [
      if (!payment && !missing)
        Borrowing(
          id: 'entry',
          debtId: 'debt',
          amountMinor: amount,
          date: date,
          note: note,
          createdAt: DateTime(2020),
          isEdited: edited,
        ),
    ],
  );
  Future<void> update(int amount, DateTime date, String? note) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('forced');
    this.amount = amount;
    this.date = date;
    this.note = note?.trim() ?? '';
    edited = true;
  }
}

class _Debts extends DebtRepository {
  _Debts(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final _Store store;
  @override
  Future<DebtSummary?> load([String? debtId]) async => store.summary;
  @override
  Future<List<Debt>> list() async => [store.summary.debt];
}

class _Payments extends PaymentRepository {
  _Payments(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final _Store store;
  @override
  Future<void> update({
    required String id,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) => store.update(amountMinor, date, note);
}

class _Borrowings extends BorrowingRepository {
  _Borrowings(this.store) : super(AppDatabase(factory: databaseFactoryFfi));
  final _Store store;
  @override
  Future<void> update({
    required String id,
    required int amountMinor,
    required DateTime date,
    String? note,
  }) => store.update(amountMinor, date, note);
}

void main() {
  Future<void> boot(
    WidgetTester tester,
    _Store store, {
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
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debtRepositoryProvider.overrideWithValue(_Debts(store)),
          paymentRepositoryProvider.overrideWithValue(_Payments(store)),
          borrowingRepositoryProvider.overrideWithValue(_Borrowings(store)),
        ],
        child: MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final summary = ref
                    .watch(debtSummaryByIdProvider('debt'))
                    .value;
                if (summary == null) return const SizedBox();
                return ListView(
                  children: [
                    if (store.payment && summary.payments.isNotEmpty)
                      PaymentListItem(payment: summary.payments.single),
                    if (!store.payment && summary.borrowings.isNotEmpty)
                      BorrowingListItem(borrowing: summary.borrowings.single),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, _Store store) async {
    await tester.tap(
      store.payment
          ? find.byType(PaymentListItem)
          : find.byType(BorrowingListItem),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'แก้ไขรายการ');
  }

  AppButton saveButton(WidgetTester tester) => tester.widget<AppButton>(
    find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'บันทึกการแก้ไข',
    ),
  );
  for (final payment in [true, false]) {
    final kind = payment ? 'payment' : 'borrowing';
    testWidgets('$kind date edit and unchanged close', (tester) async {
      final store = _Store(payment);
      await boot(tester, store);
      await open(tester, store);
      await tester.tap(find.byTooltip('ปิด').last);
      await tester.pumpAndSettle();
      expect(find.text('ละทิ้งข้อมูลที่กรอกไว้?'), findsNothing);
      expect(store.writes, 0);
      await open(tester, store);
      await tester.tap(find.byType(OutlinedButton).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();
      await tap(tester, 'ยืนยัน');
      await tap(tester, 'บันทึกการแก้ไข');
      expect(store.date, DateTime(2020, 1, 2));
      expect(store.edited, true);
    });
    testWidgets('$kind prefilled edit saves and shows both markers', (
      tester,
    ) async {
      final store = _Store(payment);
      await boot(tester, store);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await open(tester, store);
      expect(find.text('100.00'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'original',
      );
      expect(saveButton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).first, '200.50');
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.pumpAndSettle();
      await tap(tester, 'บันทึกการแก้ไข');
      expect(store.amount, 20050);
      expect(store.note, '');
      expect(store.writes, 1);
      expect(find.text('แก้ไขแล้ว'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      await tester.tap(
        payment ? find.byType(PaymentListItem) : find.byType(BorrowingListItem),
      );
      await tester.pumpAndSettle();
      expect(find.text('แก้ไขแล้ว'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    });
    testWidgets('$kind normalized unchanged and discard guard', (tester) async {
      final store = _Store(payment);
      await boot(tester, store);
      await open(tester, store);
      await tester.enterText(find.byType(TextFormField).first, '100');
      await tester.enterText(find.byType(TextFormField).last, ' original ');
      await tester.pumpAndSettle();
      expect(saveButton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('ปิด').last);
      await tester.pumpAndSettle();
      expect(find.text('ละทิ้งข้อมูลที่กรอกไว้?'), findsOneWidget);
      await tap(tester, 'ยกเลิก');
      expect(find.text('200'), findsOneWidget);
      await tester.tap(find.byTooltip('ปิด').last);
      await tester.pumpAndSettle();
      await tap(tester, 'ละทิ้งข้อมูล');
      expect(store.edited, false);
      expect(store.writes, 0);
    });
    testWidgets(
      '$kind failed save retains inputs and pending write blocks dismissal',
      (tester) async {
        final store = _Store(payment)..fail = true;
        await boot(tester, store);
        await open(tester, store);
        await tester.enterText(find.byType(TextFormField).first, '200');
        await tester.pumpAndSettle();
        await tap(tester, 'บันทึกการแก้ไข');
        expect(find.text('200'), findsOneWidget);
        expect(store.edited, false);
        store.fail = false;
        store.pending = Completer<void>();
        await tester.ensureVisible(find.text('บันทึกการแก้ไข'));
        await tester.tap(find.text('บันทึกการแก้ไข'));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(saveButton(tester).isLoading, true);
        expect(store.writes, 2);
        store.pending!.complete();
        await tester.pumpAndSettle();
        expect(store.edited, true);
      },
    );
    testWidgets('$kind small phone large text and keyboard fits edit form', (
      tester,
    ) async {
      final store = _Store(payment);
      await boot(tester, store, small: true);
      await open(tester, store);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '200');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('บันทึกการแก้ไข'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
