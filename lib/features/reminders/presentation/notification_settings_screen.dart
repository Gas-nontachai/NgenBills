import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../debt/presentation/providers/debt_providers.dart';
import 'reminder_providers.dart';
import 'reminder_settings_sheet.dart';
import 'reminder_widgets.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reminderControllerProvider);
    final summary = ref.watch(debtSummaryProvider).value;
    final controller = ref.read(reminderControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppCard(
                  color: AppColors.primarySoft,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications),
                    title: Text(
                      status.permissionAllowed == null
                          ? status.syncError
                                ? 'ตรวจสิทธิ์แจ้งเตือนไม่สำเร็จ'
                                : 'กำลังตรวจสิทธิ์แจ้งเตือน'
                          : status.permissionAllowed!
                          ? 'อนุญาตการแจ้งเตือนแล้ว'
                          : 'ยังไม่อนุญาตการแจ้งเตือน',
                    ),
                    subtitle: const Text(
                      'สิทธิ์การแจ้งเตือนในการตั้งค่าของเครื่อง',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: status.busy
                        ? null
                        : () => _run(context, controller.openSystemSettings),
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('ตั้งค่าวันครบกำหนดและแจ้งเตือน'),
                    subtitle: Text(
                      summary == null
                          ? 'เพิ่มหนี้ก่อนตั้งวันครบกำหนด'
                          : status.settings?.enabled == true
                          ? 'เปิดการแจ้งเตือนในแอปอยู่'
                          : 'ปิดการแจ้งเตือนในแอปอยู่',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: summary == null || status.busy || status.loadError
                        ? null
                        : () => ReminderSettingsSheet.open(
                            context,
                            summary.debt.id,
                            summary.debt.name,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.errorSoft,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.notifications_off_outlined,
                      color: AppColors.error,
                    ),
                    title: const Text(
                      'ปิดการแจ้งเตือนทั้งหมด',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: const Text('เก็บวันและเวลาที่ตั้งไว้'),
                    onTap:
                        status.busy ||
                            status.loadError ||
                            status.settings?.enabled != true
                        ? null
                        : () => _run(context, () async {
                            await controller.disable();
                            if (context.mounted) {
                              AppSnackBar.show(
                                context,
                                ref.read(reminderControllerProvider).syncError
                                    ? 'บันทึกสถานะปิดแล้ว แต่ยกเลิกตารางเตือนไม่สำเร็จ กรุณาลองใหม่'
                                    : 'ปิดการแจ้งเตือนแล้ว',
                              );
                            }
                          }),
                  ),
                ),
                const SizedBox(height: 16),
                const ReminderSyncNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
