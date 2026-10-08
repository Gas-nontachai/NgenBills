import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../reminders/presentation/reminder_widgets.dart';
import '../../../reminders/presentation/reminder_settings_sheet.dart';
import '../../../reminders/presentation/reminder_providers.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/services/debt_summary.dart';
import 'half_donut_chart.dart';
import 'debt_summary_row.dart';
import 'fully_paid_message.dart';
import '../providers/debt_providers.dart';
import 'account_avatar.dart';
import '../sheets/add_borrowing_sheet.dart';
import '../sheets/customize_account_sheet.dart';

class DebtProgressCard extends ConsumerWidget {
  const DebtProgressCard({super.key, required this.summary});
  final DebtSummary summary;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    child: Column(
      children: [
        Row(
          children: [
            AccountAvatar(
              iconKey: summary.debt.iconKey,
              colorKey: summary.debt.colorKey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(summary.debt.name, style: AppTypography.title),
            ),
            PopupMenuButton<String>(
              tooltip: 'เมนูหนี้',
              enabled: !ref.watch(paymentActionProvider),
              onSelected: (value) {
                switch (value) {
                  case 'borrow':
                    AddBorrowingSheet.open(context, summary);
                  case 'customize':
                    CustomizeAccountSheet.open(context, summary.debt);
                  case 'reminders':
                    ReminderSettingsSheet.open(
                      context,
                      summary.debt.id,
                      summary.debt.name,
                    );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'borrow',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_circle_outline),
                    title: Text('กู้เพิ่ม'),
                    subtitle: Text('เพิ่มยอดหนี้ พร้อมบันทึกประวัติ'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'customize',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('ปรับแต่งบัญชี'),
                    subtitle: Text('ชื่อ ไอคอน และสีบัญชี'),
                  ),
                ),
                PopupMenuItem(
                  value: 'reminders',
                  enabled:
                      !ref.watch(reminderControllerProvider).busy &&
                      !ref.watch(reminderControllerProvider).loadError,
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_outlined),
                    title: Text('ตั้งค่าการแจ้งเตือน'),
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: AppColors.primaryDark),
            ),
          ],
        ),
        if ((summary.debt.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(summary.debt.note!, style: AppTypography.small),
          ),
        ],
        const SizedBox(height: 16),
        HalfDonutChart(
          progress: summary.progress,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.isPaid
                    ? 'ชำระครบแล้ว! 🎉'
                    : 'ชำระแล้ว ${summary.progressLabel}%',
                style: AppTypography.small.copyWith(color: AppColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                Money.format(summary.remaining, decimals: summary.isPaid),
                style: AppTypography.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                summary.borrowings.isEmpty
                    ? 'จากยอดเริ่มต้น ${Money.format(summary.debt.initialAmountMinor)}'
                    : 'จากยอดหนี้รวม ${Money.format(summary.totalDebt)}',
                style: AppTypography.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        DebtSummaryRow(paid: summary.totalPaid, remaining: summary.remaining),
        const SizedBox(height: 12),
        DebtReminderBanner(summary: summary),
        if (summary.isPaid) ...[
          const SizedBox(height: 20),
          const FullyPaidMessage(),
        ],
      ],
    ),
  );
}
