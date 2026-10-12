// Capture release previews only: no golden baselines or image comparisons.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/app/theme/app_theme.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/payment/domain/entities/payment.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';
import 'package:ngenbills/features/settings/presentation/app_version_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../test/support/reminder_fakes.dart';

class _PreviewDebts extends DebtRepository {
  _PreviewDebts(this.summary) : super(AppDatabase(factory: databaseFactoryFfi));

  final DebtSummary summary;

  @override
  Future<List<Debt>> list() async => [summary.debt];
  @override
  Future<String?> defaultId() async => summary.debt.id;
  @override
  Future<DebtSummary?> load([String? debtId]) async => summary;
  @override
  Future<List<DebtSummary>> loadAll() async => [summary];
}

void main() {
  final date = DateTime(2026, 10, 12);
  final boundaryKey = GlobalKey();

  setUpAll(() async {
    final kanit = FontLoader('Kanit');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      kanit.addFont(rootBundle.load('assets/fonts/Kanit-$weight.ttf'));
    }
    // Widget capture has no native font fallback; load the runner's emoji font.
    final emoji = File(
      Platform.isMacOS
          ? '/System/Library/Fonts/Apple Color Emoji.ttc'
          : '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    );
    final emojiBytes = await emoji.readAsBytes();
    await kanit.load();
    await (FontLoader(
      'ReleaseEmoji',
    )..addFont(Future.value(ByteData.sublistView(emojiBytes)))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('Capture key screens for Android release', (tester) async {
    await withClock(Clock.fixed(date), () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<void> boot(DebtSummary summary) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: ProviderScope(
              overrides: [
                debtRepositoryProvider.overrideWithValue(
                  _PreviewDebts(summary),
                ),
                debtClockProvider.overrideWithValue(() => date),
                appVersionProvider.overrideWith(
                  (ref) async => const String.fromEnvironment(
                    'RELEASE_VERSION',
                    defaultValue: '1.0.0',
                  ),
                ),
                reminderRepositoryProvider.overrideWithValue(
                  MemoryReminderRepository(),
                ),
                notificationServiceProvider.overrideWithValue(
                  FakeNotificationService(),
                ),
              ],
              child: NgenBillsApp(
                theme: appTheme().copyWith(
                  textTheme: appTheme().textTheme.apply(
                    fontFamilyFallback: const ['ReleaseEmoji'],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/logo.png'),
            boundaryKey.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/release-screenshots');
            await directory.create(recursive: true);
            await File('${directory.path}/$name.png').writeAsBytes(
              bytes!.buffer.asUint8List(
                bytes.offsetInBytes,
                bytes.lengthInBytes,
              ),
            );
          } finally {
            image.dispose();
          }
        });
      }

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      Future<void> closeSheet() => tap(find.byTooltip('ปิด'));

      Future<void> accountMenu(String label) async {
        await tap(find.byTooltip('เมนูหนี้'));
        await tap(find.text(label).last);
      }

      final debt = Debt(
        id: 'preview-debt',
        name: 'บัตรเครดิต',
        initialAmountMinor: 1000000,
        createdAt: date,
        updatedAt: date,
      );
      await boot(
        DebtSummary(debt, [
          Payment(
            id: 'preview-payment',
            debtId: debt.id,
            amountMinor: 300000,
            date: DateTime(2026, 10, 1),
            note: 'จ่ายผ่านธนาคาร',
            createdAt: DateTime(2026, 10, 1),
          ),
        ]),
      );
      expect(find.text('บัตรเครดิต'), findsOneWidget);
      await capture('home');

      await tester.tap(find.text('บันทึกการจ่าย').first);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsWidgets);
      await capture('payment');

      await closeSheet();
      await tap(find.text('ชำระหนี้').first);
      expect(find.text('รายละเอียดการจ่าย'), findsOneWidget);
      await capture('payment-detail');
      await closeSheet();

      await accountMenu('ปรับแต่งบัญชี');
      expect(find.text('เลือกไอคอน'), findsOneWidget);
      await capture('account');
      await closeSheet();

      await accountMenu('ตั้งค่าการแจ้งเตือน');
      expect(find.text('บันทึกการตั้งค่า'), findsOneWidget);
      await capture('notifications');
      await closeSheet();

      await tap(find.byTooltip('ตั้งค่า'));
      expect(find.text('ตั้งค่า'), findsOneWidget);
      await capture('settings');

      await tap(find.text('สำรองข้อมูล'));
      expect(find.text('สำรองและเลือกที่บันทึก'), findsOneWidget);
      await capture('backup');
      await tap(find.text('ยกเลิก'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
