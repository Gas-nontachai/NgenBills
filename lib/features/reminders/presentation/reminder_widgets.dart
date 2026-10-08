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
    final countdownColor = summary.isPaid || days == null
        ? AppColors.text
        : days <= 3
        ? AppColors.dueUrgent
        : days <= 7
        ? AppColors.dueSoon
        : AppColors.text;
    final subtitle = summary.isPaid
        ? 'ชำระครบแล้ว · หยุดแจ้งเตือน'
        : settings == null
        ? 'เลือกวันชำระและเวลาเตือน'
        : !settings.enabled
        ? 'ปิดการแจ้งเตือนอยู่'
        : status.permissionAllowed == false
        ? 'ยังไม่ได้รับอนุญาตแจ้งเตือน'
        : settings.advanceDays.isEmpty && !settings.remindOnDueDate
        ? 'ไม่ได้เลือกวันแจ้งเตือน'
        : null;
    final advance = settings?.advanceDays.toList() ?? <int>[];
    advance.sort((a, b) => b.compareTo(a));
    final parts = [
      if (advance.isNotEmpty) '${advance.join('/')} วันก่อน',
      if (settings?.remindOnDueDate ?? false) 'วันชำระ',
    ];
    final time = settings == null
        ? ''
        : '${settings.hour.toString().padLeft(2, '0')}:${settings.minute.toString().padLeft(2, '0')} น.';
    Widget cell(
      IconData icon,
      String label,
      String value, {
      bool emphasis = false,
      Color? textColor,
    }) => Semantics(
      label: label,
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: emphasis ? 13 : 12,
                height: 1.4,
                fontWeight: emphasis ? FontWeight.w500 : FontWeight.w400,
                color:
                    textColor ??
                    (emphasis ? AppColors.text : AppColors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        onTap: status.busy || status.loadError
            ? null
            : () => ReminderSettingsSheet.open(
                context,
                summary.debt.id,
                summary.debt.name,
              ),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: settings == null
                ? Row(
                    children: [
                      Expanded(
                        child: cell(
                          Icons.calendar_today_outlined,
                          'ครบกำหนด',
                          'ตั้งวันครบกำหนดและแจ้งเตือน',
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final dueCell = cell(
                        Icons.calendar_today_outlined,
                        'ครบกำหนด',
                        summary.isPaid
                            ? 'ชำระครบแล้ว'
                            : days == 0
                            ? 'วันนี้'
                            : 'อีก $days วัน',
                        emphasis: true,
                        textColor: countdownColor,
                      );
                      final reminderCell = cell(
                        Icons.notifications_outlined,
                        'แจ้งเตือน',
                        subtitle ?? '${parts.join(' · ')}\n$time',
                      );
                      if (constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(16) > 22) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  dueCell,
                                  const SizedBox(height: 8),
                                  reminderCell,
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 4, child: dueCell),
                          const SizedBox(width: 12),
                          Expanded(flex: 7, child: reminderCell),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
