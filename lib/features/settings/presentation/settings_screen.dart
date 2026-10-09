import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../backup/data/backup_file_service.dart';
import '../../backup/data/backup_service.dart';
import '../../backup/presentation/backup_sheets.dart';
import '../../debt/presentation/providers/debt_providers.dart';
import '../../reminders/presentation/reminder_providers.dart';
import '../../reminders/presentation/reminder_widgets.dart';
import 'settings_widgets.dart';

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
final backupFileServiceProvider = Provider((ref) => BackupFileService());

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _operation;
  bool _reviewing = false;

  Future<bool?> _review(Widget sheet) async {
    setState(() => _reviewing = true);
    try {
      return await showAppSheet<bool>(context, sheet);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_operation != null || ref.read(paymentActionProvider)) return;
    setState(() => _operation = label);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        AppSnackBar.show(
          context,
          error is AppException
              ? error.message
              : '$labelไม่สำเร็จ กรุณาลองอีกครั้ง',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _operation = null);
    }
  }

  Future<void> _backup() => _run('สำรองข้อมูล', () async {
    final confirmed = await _review(const BackupInfoSheet());
    if (!mounted || confirmed != true) return;
    final bytes = await ref.read(backupServiceProvider).export();
    if (!mounted) return;
    final saved = await ref.read(backupFileServiceProvider).save(bytes);
    if (mounted && saved) {
      AppSnackBar.show(context, 'บันทึกไฟล์สำรองแล้ว');
    }
  });

  Future<void> _restore() => _run('กู้คืนข้อมูล', () async {
    final file = await ref.read(backupFileServiceProvider).pick();
    if (!mounted || file == null) return;
    final service = ref.read(backupServiceProvider);
    final snapshot = service.decode(file.bytes);
    final confirmed = await _review(
      RestorePreviewSheet(snapshot: snapshot, fileName: file.name),
    );
    if (!mounted || confirmed != true) return;
    await ref
        .read(reminderControllerProvider.notifier)
        .restoreData(() => service.restore(snapshot));
    if (!mounted) return;
    final reminders = ref.read(reminderControllerProvider);
    final notice = reminders.syncError || reminders.loadError;
    AppSnackBar.show(
      context,
      notice
          ? 'กู้คืนข้อมูลแล้ว แต่จัดตารางแจ้งเตือนไม่สำเร็จ ลองใหม่ได้ในหน้าตั้งค่า'
          : 'กู้คืนข้อมูลและการตั้งค่าแล้ว',
    );
    context.go('/');
  });

  @override
  Widget build(BuildContext context) {
    final writing = ref.watch(paymentActionProvider);
    final busy = _operation != null || writing;
    final reminders = ref.watch(reminderControllerProvider);
    final notificationLabel = reminders.permissionAllowed == true
        ? 'อนุญาตแล้ว · จัดการวันและเวลาเตือน'
        : reminders.permissionAllowed == false
        ? 'ยังไม่อนุญาต · จัดการวันและเวลาเตือน'
        : 'จัดการสิทธิ์ วันและเวลาเตือน';

    return PopScope(
      canPop: _operation == null,
      child: Scaffold(
        appBar: AppBar(title: const Text('ตั้งค่า')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    color: AppColors.primarySoft,
                    child: Row(
                      children: [
                        const AppLogo(size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'เงินบิล — NgenBills',
                                style: AppTypography.title,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ดูแลข้อมูลและตั้งค่าให้เหมาะกับคุณ',
                                style: AppTypography.small.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (busy && !_reviewing) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _operation == null
                                  ? 'กำลังบันทึกข้อมูล…'
                                  : 'กำลัง$_operation…',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SettingsSectionTitle('ข้อมูลของคุณ'),
                  SettingsTile(
                    uniform: true,
                    icon: Icons.file_download_outlined,
                    title: 'สำรองข้อมูล',
                    subtitle: 'บันทึกข้อมูลและการตั้งค่าเป็นไฟล์ .ngenbills',
                    onTap: busy ? null : _backup,
                  ),
                  SettingsTile(
                    uniform: true,
                    icon: Icons.restore_rounded,
                    title: 'กู้คืนข้อมูล',
                    subtitle:
                        'เลือกไฟล์สำรองเพื่อแทนที่ข้อมูลและการตั้งค่าทั้งหมด',
                    onTap: busy ? null : _restore,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'ไฟล์สำรองไม่เข้ารหัส โปรดเก็บในที่ปลอดภัย '
                      'แอพไม่อัปโหลดไฟล์ไปยัง server ของผู้ให้บริการ',
                      style: AppTypography.caption,
                    ),
                  ),
                  const SettingsSectionTitle('การแจ้งเตือน'),
                  SettingsTile(
                    uniform: true,
                    icon: Icons.notifications_active_outlined,
                    title: 'การแจ้งเตือน',
                    subtitle: notificationLabel,
                    onTap: busy
                        ? null
                        : () => context.push('/settings/notifications'),
                  ),
                  const ReminderSyncNotice(),
                  const SettingsSectionTitle('เกี่ยวกับและข้อกำหนด'),
                  AppCard(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        SettingsLink(
                          icon: Icons.description_outlined,
                          title: 'ข้อกำหนดการใช้งาน',
                          onTap: busy
                              ? null
                              : () => context.push('/settings/terms'),
                        ),
                        const Divider(
                          height: 1,
                          thickness: .5,
                          indent: 52,
                          endIndent: 12,
                          color: AppColors.border,
                        ),
                        SettingsLink(
                          icon: Icons.privacy_tip_outlined,
                          title: 'นโยบายความเป็นส่วนตัว',
                          onTap: busy
                              ? null
                              : () => context.push('/settings/privacy'),
                        ),
                        const Divider(
                          height: 1,
                          thickness: .5,
                          indent: 52,
                          endIndent: 12,
                          color: AppColors.border,
                        ),
                        SettingsLink(
                          icon: Icons.code_rounded,
                          title: 'ใบอนุญาตซอฟต์แวร์',
                          onTap: busy
                              ? null
                              : () => showLicensePage(
                                  context: context,
                                  applicationName: 'เงินบิล — NgenBills',
                                  applicationIcon: const AppLogo(size: 64),
                                  applicationLegalese: '© 2026 Nonthachai Phosri\nสงวนลิขสิทธิ์ตัวแอพ',
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '© 2026 Nonthachai Phosri\nค่อย ๆ จ่าย ค่อย ๆ ไป 🌱',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
