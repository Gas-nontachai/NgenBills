import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/debt/presentation/sheets/account_picker_sheet.dart';
import 'package:ngenbills/features/debt/presentation/widgets/account_swipe_card.dart';
import 'package:ngenbills/features/payment/data/repositories/payment_repository.dart';
import 'package:ngenbills/features/reminders/data/reminder_repository.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/reminder_fakes.dart';

class _MemoryDebts extends DebtRepository {
  _MemoryDebts() : super(AppDatabase(factory: databaseFactoryFfi));
  final accounts = [
    for (var i = 0; i < 2; i++)
      Debt(
        id: '$i',
        name: i == 0 ? 'บัญชีแรก' : 'บัญชีสอง',
        initialAmountMinor: (i + 1) * 10000,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
  String primary = '0';
  @override
  Future<List<Debt>> list() async => accounts;
  @override
  Future<String?> defaultId() async => primary;
  @override
  Future<void> setDefault(String id) async {
    primary = id;
  }

  @override
  Future<DebtSummary?> load([String? id]) async =>
      DebtSummary(accounts.firstWhere((a) => a.id == (id ?? '0')), []);
  @override
  Future<List<DebtSummary>> loadAll() async => [
    for (final a in accounts) DebtSummary(a, []),
  ];
}

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase database;
  late DebtRepository debts;
  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    debts = DebtRepository(database);
  });
  tearDown(() => database.close());

  test(
    '20 accounts isolate history and default deletion repairs preference',
    () async {
      final ids = <String>[];
      for (var i = 0; i < 20; i++) {
        ids.add(await debts.create(name: 'บัญชี $i', amountMinor: 10000));
      }
      expect(await debts.defaultId(), ids.first);
      expect((await debts.list()).length, 20);
      await PaymentRepository(database)
          .add(debtId: ids[1], amountMinor: 1000, date: DateTime(2026, 1, 1));
      expect((await debts.load(ids[1]))!.remaining, 9000);
      expect((await debts.load(ids[0]))!.history, isEmpty);
      await debts.setDefault(ids[1]);
      await debts.delete(ids[1]);
      expect(await debts.defaultId(), ids.first);
      expect((await debts.loadAll()).every((s) => s.history.isEmpty), true);
      for (final id in ids) {
        await debts.delete(id);
      }
      expect(await debts.defaultId(), isNull);
      expect(await debts.list(), isEmpty);
    },
  );

  test(
    'Legacy preference backfill and default persist through reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('multi_debt_');
      final path = '${dir.path}/db.sqlite';
      final first = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      try {
        final repo = DebtRepository(first);
        final a = await repo.create(name: 'เดิม', amountMinor: 12345);
        await (await first.instance).delete(
          'app_preferences',
          where: 'key = ?',
          whereArgs: ['default_debt_id'],
        );
        expect(await repo.defaultId(), a);
        final b = await repo.create(name: 'ใหม่', amountMinor: 23456);
        await repo.setDefault(b);
        var closed = false;
        final closing = first.close().then((_) {
          closed = true;
        });
        await first.close();
        await Future<void>.microtask(() {});
        expect(closed, true);
        await closing;
        final reopened = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        try {
          final repo = DebtRepository(reopened);
          expect(await repo.defaultId(), b);
          expect((await repo.load(a))!.remaining, 12345);
        } finally {
          await reopened.close();
        }
      } finally {
        await first.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('Multiple schedules share 60 slots; paying and deleting only remove that account', () async {
    final a = await debts.create(name: 'A', amountMinor: 10000);
    final b = await debts.create(name: 'B', amountMinor: 20000);
    final service = FakeNotificationService();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        notificationServiceProvider.overrideWithValue(service),
        reminderClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 8),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(reminderControllerProvider.notifier);
    for (final id in [a, b]) {
      await controller.save(
        ReminderSettings(
          debtId: id,
          dueDay: 27,
          enabled: true,
          advanceDays: {1, 3, 7},
        ),
      );
    }
    expect(service.pending.length, 60);
    expect(service.pending.map((r) => r.id).toSet().length, 60);
    expect(service.pending.map((r) => r.debtId).toSet(), {a, b});
    container.read(selectedDebtIdProvider.notifier).select(b);
    await PaymentRepository(database)
        .add(debtId: a, amountMinor: 10000, date: DateTime(2026, 1, 1));
    await controller.refresh();
    expect(service.pending.every((r) => r.debtId == b), true);
    await debts.delete(a);
    await controller.refresh();
    expect(service.pending, isNotEmpty);
    await controller.disable();
    expect(service.pending, isEmpty);
    expect((await ReminderRepository(database).load(b))!.enabled, false);
  });

  late _MemoryDebts memory;
  Future<ProviderContainer> boot(
    WidgetTester tester, {
    bool seed = true,
  }) async {
    if (seed) memory = _MemoryDebts();
    final container = ProviderContainer(
      overrides: [
        debtRepositoryProvider.overrideWithValue(memory),
        reminderRepositoryProvider.overrideWithValue(
          MemoryReminderRepository(),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'Swipe, picker, background, write lock and restart select correct account',
    (tester) async {
      final container = await boot(tester);
      final accounts = await memory.list();
      expect(find.text('บัญชีแรก'), findsOneWidget);
      expect(find.text('เพิ่มบัญชี'), findsNothing);
      await tester.tap(find.text('บัญชีแรก'));
      await tester.pumpAndSettle();
      expect(find.text('เพิ่มบัญชี'), findsOneWidget);
      await tester.tap(find.byTooltip('ปิด'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(AccountSwipeCard), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text('บัญชีสอง'), findsOneWidget);
      expect(find.text('฿200'), findsNWidgets(2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('บัญชีสอง'), findsOneWidget);
      await tester.tap(find.text('2 / 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('บัญชีแรก').last);
      await tester.pumpAndSettle();
      expect(find.text('฿100'), findsNWidgets(2));
      final pending = Completer<void>();
      final write = container
          .read(paymentActionProvider.notifier)
          .run(() => pending.future);
      await tester.pump();
      expect(find.text('กำลังบันทึก…'), findsOneWidget);
      await tester.drag(find.byType(AccountSwipeCard), const Offset(-150, 0));
      await tester.pump();
      expect(find.text('บัญชีแรก'), findsOneWidget);
      pending.complete();
      await write;
      await tester.pumpAndSettle();
      await memory.setDefault(accounts[1].id);
      await tester.pumpWidget(const SizedBox());
      final restarted = await boot(tester, seed: false);
      expect(find.text('บัญชีสอง'), findsOneWidget);
      restarted
          .read(selectedDebtIdProvider.notifier)
          .select('deleted-notification-account');
      await tester.pumpAndSettle();
      expect(find.text('บัญชีสอง'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [1, 10, 20]) {
    testWidgets(
      'Picker handles $count accounts, search, duplicate and long names',
      (tester) async {
        final accounts = [
          for (var i = 0; i < count; i++)
            Debt(
              id: '$i',
              name: i == 0 ? 'ชื่อบัญชียาวมาก' * 8 : 'บัญชีซ้ำ',
              initialAmountMinor: 10000,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
        ];
        AccountPickerResult? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await AccountPickerSheet.open(
                      context,
                      accounts,
                      '${count - 1}',
                      '0',
                    );
                  },
                  child: const Text('เปิด'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        expect(find.text('เลือกบัญชี'), findsOneWidget);
        if (count == 20) {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.8;
          tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
            tester.view.resetViewInsets();
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.enterText(find.byType(TextField), 'ไม่พบ');
        await tester.pumpAndSettle();
        expect(find.text('ไม่พบบัญชี'), findsOneWidget);
        await tester.tap(
          count == 20 ? find.byTooltip('ล้างคำค้น') : find.text('ล้างคำค้น'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('เพิ่มบัญชี'));
        await tester.pumpAndSettle();
        expect(result!.create, true);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Swipe hold requires distance and time; cancelled hold never creates',
    (tester) async {
      var creates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountSwipeCard(
              enabled: true,
              last: true,
              onPrevious: () {},
              onNext: () {},
              onCreate: () => creates++,
              child: const SizedBox(
                width: 350,
                height: 300,
                child: Text('บัญชี'),
              ),
            ),
          ),
        ),
      );
      Future<TestGesture> drag() async {
        final gesture = await tester.startGesture(const Offset(250, 150));
        await gesture.moveBy(const Offset(-30, 0));
        await gesture.moveBy(const Offset(-100, 0));
        return gesture;
      }

      var gesture = await drag();
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      expect(creates, 0);
      gesture = await drag();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('ปล่อยเพื่อเพิ่มบัญชี'), findsOneWidget);
      await gesture.moveBy(const Offset(110, 0));
      await gesture.up();
      await tester.pump();
      expect(creates, 0);
      gesture = await drag();
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.cancel();
      await tester.pump();
      expect(creates, 0);
      gesture = await drag();
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();
      expect(creates, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Picker visual reference', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fonts = FontLoader('Kanit')
      ..addFont(rootBundle.load('assets/fonts/Kanit-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await boot(tester);
    await tester.tap(find.text('บัญชีแรก'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NgenBillsApp),
      matchesGoldenFile(
        Platform.isLinux
            ? 'goldens/linux/account_picker.png'
            : 'goldens/account_picker.png',
      ),
    );
  });
}
