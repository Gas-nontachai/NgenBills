import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../debt/domain/services/debt_summary.dart';
import '../domain/reminder_schedule.dart';
import 'reminder_providers.dart';
import 'reminder_settings_sheet.dart';

class ReminderSyncNotice extends ConsumerWidget {
  const ReminderSyncNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reminderControllerProvider);
    if (!status.syncError && !status.loadError) return const SizedBox.shrink();
    return AppCard(
      color: AppColors.errorSoft,
      child: Column(
        children: [
          Text(
            status.loadError
                ? 'โหลดการตั้งค่าเตือนไม่สำเร็จ'
                : 'จัดตารางแจ้งเตือนไม่สำเร็จ',
          ),
          TextButton(
            onPressed: status.busy
                ? null
                : () => ref.read(reminderControllerProvider.notifier).refresh(),
            child: const Text('ลองจัดตารางใหม่'),
          ),
        ],
      ),
    );
  }
}

class DebtReminderBanner extends ConsumerWidget {
  const DebtReminderBanner({super.key, required this.summary});
  final DebtSummary summary;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reminderControllerProvider);
    final settings = status.settings;
    final now = tz.TZDateTime.from(
      ref.watch(reminderClockProvider)(),
      status.zone ?? tz.UTC,
    );
    final due = settings == null
        ? null
        : ReminderSchedule.nextDueDate(settings, now);
    final days = due == null ? null : ReminderSchedule.daysUntil(due, now);
    final subtitle = summary.isPaid
        ? 'ชำระครบแล้ว · หยุดแจ้งเตือน'
        : settings == null
        ? 'เลือกวันชำระและเวลาเตือน'
        : !settings.enabled
        ? 'ปิดการแจ้งเตือนอยู่'
        : status.permissionAllowed == false
        ? 'ยังไม่ได้รับอนุญาตแจ้งเตือน'
        : settings.daysBefore == 0 && !settings.remindOnDueDate
        ? 'ไม่ได้เลือกวันแจ้งเตือน'
        : null;
    return Column(
      children: [
        AppCard(
          color: AppColors.primarySoft,
          child: InkWell(
            onTap: status.busy || status.loadError
                ? null
                : () => ReminderSettingsSheet.open(
                    context,
                    summary.debt.id,
                    summary.debt.name,
                  ),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings == null
                            ? 'ตั้งวันครบกำหนดและแจ้งเตือน'
                            : 'ครบกำหนดวันที่ ${settings.dueDay} ของเดือน',
                      ),
                      if (subtitle != null)
                        Text(subtitle, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (days != null && !summary.isPaid)
                  Text(
                    days == 0 ? 'วันนี้' : 'อีก $days วัน',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const ReminderSyncNotice(),
      ],
    );
  }
}
