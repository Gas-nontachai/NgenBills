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
  const DebtProgressCard({
    super.key,
    required this.summary,
    this.accountHeader,
    this.accountNavigation,
  });
  final DebtSummary summary;
  final Widget? accountHeader;
  final Widget? accountNavigation;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 19;
            final menu = SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                tooltip: 'เมนูหนี้',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
                padding: EdgeInsets.zero,
                menuPadding: const EdgeInsets.all(8),
                color: AppColors.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 8,
                shadowColor: AppColors.text.withValues(alpha: 0.14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border),
                ),
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
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: _AccountMenuAction(
                      icon: Icons.add_rounded,
                      title: 'กู้เพิ่ม',
                      subtitle: 'เพิ่มยอดหนี้และบันทึกประวัติ',
                      prominent: true,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    enabled: false,
                    height: 9,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(height: 9, color: AppColors.border),
                  ),
                  const PopupMenuItem(
                    value: 'customize',
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: _AccountMenuAction(
                      icon: Icons.edit_outlined,
                      title: 'ปรับแต่งบัญชี',
                      subtitle: 'เปลี่ยนชื่อ ไอคอน และสีบัญชี',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reminders',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabled:
                        !ref.watch(reminderControllerProvider).busy &&
                        !ref.watch(reminderControllerProvider).loadError,
                    child: _AccountMenuAction(
                      icon: Icons.notifications_none_rounded,
                      title: 'ตั้งค่าการแจ้งเตือน',
                      subtitle: 'จัดการเตือนวันชำระ',
                      enabled:
                          !ref.watch(reminderControllerProvider).busy &&
                          !ref.watch(reminderControllerProvider).loadError,
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: AppColors.primaryDark),
              ),
            );
            return Column(
              children: [
                Row(
                  children: [
                    AccountAvatar(
                      iconKey: summary.debt.iconKey,
                      colorKey: summary.debt.colorKey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          accountHeader ??
                          Text(summary.debt.name, style: AppTypography.title),
                    ),
                    if (!stacked && accountNavigation != null) ...[
                      const SizedBox(width: 8),
                      accountNavigation!,
                    ],
                    menu,
                  ],
                ),
                if (stacked && accountNavigation != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: accountNavigation!,
                  ),
                ],
              ],
            );
          },
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

class _AccountMenuAction extends StatelessWidget {
  const _AccountMenuAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.prominent = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool prominent;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.45,
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: prominent ? AppColors.primarySoft : AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.body.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.secondary,
        ),
      ],
    ),
  );
}
