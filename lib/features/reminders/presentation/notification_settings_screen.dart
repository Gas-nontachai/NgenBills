import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../core/widgets/sheets/app_confirm_sheet.dart';
import '../../debt/presentation/providers/debt_providers.dart';
import 'reminder_providers.dart';
import 'reminder_settings_sheet.dart';
import 'reminder_widgets.dart';
import '../../debt/presentation/widgets/account_avatar.dart';
import '../../settings/presentation/settings_widgets.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _disabling = false;
  bool _applyingDisable = false;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) AppSnackBar.failure(context, error);
    }
  }

  Future<void> _confirmDisableAll() async {
    if (_disabling) return;
    setState(() => _disabling = true);
    try {
      await _run(context, () async {
        final confirmed = await showAppSheet<bool>(
          context,
          AppConfirmSheet(
            title: 'ปิดการแจ้งเตือนทั้งหมด?',
            icon: Icons.notifications_off_outlined,
            message:
                'จะหยุดการแจ้งเตือนหนี้ทุกบัญชี โดยเก็บวันและเวลาเดิมไว้ '
                'คุณเปิดเตือนรายบัญชีอีกครั้งได้ภายหลัง '
                'สิทธิ์แจ้งเตือนของเครื่องจะไม่เปลี่ยน',
            confirmLabel: 'ยืนยันปิดการแจ้งเตือนทั้งหมด',
            onConfirm: () => Navigator.of(context).pop(true),
            onCancel: () => Navigator.of(context).pop(false),
          ),
        );
        if (!mounted || confirmed != true) return;
        setState(() => _applyingDisable = true);
        await ref.read(reminderControllerProvider.notifier).disable();
        if (!mounted) return;
        AppSnackBar.show(
          context,
          ref.read(reminderControllerProvider).syncError ||
                  ref.read(reminderControllerProvider).loadError
              ? 'บันทึกสถานะปิดแล้ว แต่ยกเลิกตารางเตือนไม่สำเร็จ กรุณาลองใหม่'
              : 'ปิดการแจ้งเตือนทุกบัญชีแล้ว',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _disabling = false;
          _applyingDisable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(reminderControllerProvider);
    final accountsState = ref.watch(accountsProvider);
    final accounts = accountsState.value ?? [];
    final writing = ref.watch(paymentActionProvider);
    final controller = ref.read(reminderControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.primarySoft,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        size: 24,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เตือนก่อนวันชำระ',
                              style: AppTypography.title.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'ตั้งวันและเวลาแยกได้ทุกบัญชี',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SettingsSectionTitle('สิทธิ์ของเครื่อง'),
                SettingsTile(
                  compact: true,
                  icon: status.permissionAllowed == true
                      ? Icons.notifications_on_outlined
                      : Icons.notifications_none_outlined,
                  title: status.permissionAllowed == null
                      ? status.syncError
                            ? 'ตรวจสิทธิ์แจ้งเตือนไม่สำเร็จ'
                            : 'กำลังตรวจสิทธิ์แจ้งเตือน'
                      : status.permissionAllowed!
                      ? 'อนุญาตการแจ้งเตือนแล้ว'
                      : 'ยังไม่อนุญาตการแจ้งเตือน',
                  subtitle: 'จัดการสิทธิ์ในการตั้งค่าของเครื่อง',
                  onTap: status.busy || writing
                      ? null
                      : () => _run(context, controller.openSystemSettings),
                ),
                const SettingsSectionTitle('แจ้งเตือนรายบัญชี'),
                if (accountsState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (accountsState.hasError)
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text('โหลดบัญชีไม่สำเร็จ'),
                        TextButton(
                          onPressed: () => ref.invalidate(accountsProvider),
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                if (accounts.isNotEmpty)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < accounts.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final debt = accounts[index];
                              return ListTile(
                                dense: true,
                                minTileHeight: 64,
                                horizontalTitleGap: 10,
                                minLeadingWidth: 32,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                leading: AccountAvatar(
                                  size: 32,
                                  iconKey: debt.iconKey,
                                  colorKey: debt.colorKey,
                                ),
                                title: Text(
                                  debt.name,
                                  style: AppTypography.title.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  status.loadError
                                      ? 'โหลดการตั้งค่าไม่สำเร็จ'
                                      : status.forDebt(debt.id)?.enabled == true
                                      ? 'เปิดเตือน · ครบกำหนดวันที่ ${status.forDebt(debt.id)!.dueDay}'
                                      : status.forDebt(debt.id) == null
                                      ? 'ยังไม่ได้ตั้งวันครบกำหนด'
                                      : 'ปิดเตือนอยู่',
                                  style: AppTypography.caption.copyWith(
                                    height: 1.4,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: AppColors.secondary,
                                ),
                                onTap:
                                    status.busy || status.loadError || writing
                                    ? null
                                    : () => ReminderSettingsSheet.open(
                                        context,
                                        debt.id,
                                        debt.name,
                                      ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                if (accounts.isEmpty &&
                    !accountsState.isLoading &&
                    !accountsState.hasError)
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ยังไม่มีบัญชีสำหรับตั้งเตือน',
                          style: AppTypography.title.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'เพิ่มบัญชีหรือกู้คืนข้อมูลจากหน้าตั้งค่า',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'ตั้งเตือนสูงสุด 60 รายการใกล้ที่สุดรวมทุกบัญชี ตารางจะเติมเมื่อเปิดแอปหรือข้อมูลเปลี่ยน หากไม่เปิดแอปจนตารางหมดจะไม่มีการเติมอัตโนมัติ',
                    style: AppTypography.caption,
                  ),
                ),
                const SettingsSectionTitle('จัดการการแจ้งเตือน'),
                SettingsTile(
                  compact: true,
                  destructive: true,
                  icon: Icons.notifications_off_outlined,
                  title: 'ปิดการแจ้งเตือนทั้งหมด',
                  subtitle: _applyingDisable
                      ? 'กำลังปิดการแจ้งเตือนทุกบัญชี…'
                      : 'เก็บวันและเวลาเดิมไว้ เปิดใหม่ได้ภายหลัง',
                  // Opening confirmation needs no enabled reminders or loaded
                  // status. The controller queues the write and reports errors.
                  onTap: _disabling ? null : _confirmDisableAll,
                ),
                const SizedBox(height: 8),
                const ReminderSyncNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
