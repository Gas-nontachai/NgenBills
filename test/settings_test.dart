import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/app/app.dart';
import 'package:ngenbills/core/database/app_database.dart';
import 'package:ngenbills/features/backup/data/backup_file_service.dart';
import 'package:ngenbills/features/backup/data/backup_service.dart';
import 'package:ngenbills/features/debt/data/repositories/debt_repository.dart';
import 'package:ngenbills/features/debt/presentation/providers/debt_providers.dart';
import 'package:ngenbills/features/reminders/presentation/reminder_providers.dart';
import 'package:ngenbills/features/settings/presentation/settings_screen.dart';

import 'package:ngenbills/features/debt/domain/entities/debt.dart';
import 'package:ngenbills/features/debt/domain/services/debt_summary.dart';

import 'support/reminder_fakes.dart';

class _EmptyDebts extends DebtRepository {
  _EmptyDebts(super.database);
  @override
  Future<List<Debt>> list() async => [];
  @override
  Future<String?> defaultId() async => null;
  @override
  Future<DebtSummary?> load([String? id]) async => null;
  @override
  Future<List<DebtSummary>> loadAll() async => [];
}

class _Backup extends BackupService {
  _Backup(super.database);
  int restores = 0;
  @override
  Future<void> restore(BackupSnapshot snapshot) async {
    restores++;
  }

  @override
  Future<Uint8List> export() async => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'app': 'ngenbills',
        'formatVersion': 1,
        'schemaVersion': 1,
        'createdAt': '2026-10-09T00:00:00Z',
        'data': {
          for (final table in [
            'debts',
            'payments',
            'borrowings',
            'reminder_settings',
            'app_preferences',
          ])
            table: [],
        },
      }),
    ),
  );
}

class _Files extends BackupFileService {
  int saves = 0;
  Uint8List? saved;
  PickedBackupFile? picked;
  @override
  Future<bool> save(Uint8List bytes) async {
    saves++;
    saved = bytes;
    return true;
  }

  @override
  Future<PickedBackupFile?> pick() async => picked;
}

void main() {
  setUpAll(sqfliteFfiInit);
  late AppDatabase database;
  late _Files files;
  late _Backup backup;
  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    files = _Files();
    backup = _Backup(database);
  });
  tearDown(() => database.close());
  Future<void> tap(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.text(text),
        150,
        scrollable: find.byType(Scrollable).last,
      );
    }
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          debtRepositoryProvider.overrideWithValue(_EmptyDebts(database)),
          backupServiceProvider.overrideWithValue(backup),
          backupFileServiceProvider.overrideWithValue(files),
          reminderRepositoryProvider.overrideWithValue(
            MemoryReminderRepository(),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
        ],
        child: const NgenBillsApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ตั้งค่าและกู้คืนข้อมูล'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Backup explains contents and privacy before saving; cancellation does not save',
    (tester) async {
      await boot(tester);
      await tap(tester, 'สำรองข้อมูล');
      expect(files.saves, 0);
      expect(find.text('บัญชีหนี้ทั้งหมด'), findsOneWidget);
      expect(find.text('ประวัติทั้งหมด'), findsOneWidget);
      expect(find.text('การตั้งค่าแอพ'), findsOneWidget);
      expect(find.text('ไฟล์ไม่เข้ารหัสและไม่มีรหัสผ่าน'), findsOneWidget);
      await tap(tester, 'ยกเลิก');
      expect(files.saves, 0);
      await tap(tester, 'สำรองข้อมูล');
      await tap(tester, 'สำรองและเลือกที่บันทึก');
      expect(files.saves, 1);
      expect(BackupService(database).decode(files.saved!).accountCount, 0);
    },
  );

  testWidgets(
    'Cancelling file selection and rejecting damaged backup preserve existing data',
    (tester) async {
      await boot(tester);
      await tap(tester, 'กู้คืนข้อมูล');
      expect(find.text('ตั้งค่า'), findsOneWidget);
      files.picked = PickedBackupFile(
        name: 'bad.ngenbills',
        bytes: Uint8List.fromList([255]),
      );
      await tap(tester, 'กู้คืนข้อมูล');
      expect(find.textContaining('ไฟล์สำรองไม่ถูกต้อง'), findsOneWidget);
      expect(backup.restores, 0);
    },
  );

  testWidgets('Offline legal documents and licenses open from Settings', (
    tester,
  ) async {
    await boot(tester);
    for (final label in ['ข้อกำหนดการใช้งาน', 'นโยบายความเป็นส่วนตัว']) {
      await tap(tester, label);
      expect(find.textContaining('Nonthachai Phosri'), findsWidgets);
      expect(
        find.textContaining('nontachimuraproduction@gmail.com'),
        findsWidgets,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    await tap(tester, 'ใบอนุญาตซอฟต์แวร์');
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
