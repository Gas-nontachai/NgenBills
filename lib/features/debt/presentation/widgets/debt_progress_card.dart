import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/services/debt_summary.dart';
import 'half_donut_chart.dart';
import 'debt_summary_row.dart';
import 'fully_paid_message.dart';

class DebtProgressCard extends StatelessWidget {
  const DebtProgressCard({super.key, required this.summary});
  final DebtSummary summary;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 23,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(summary.debt.name, style: AppTypography.title),
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
        const SizedBox(height: 28),
        HalfDonutChart(
          progress: summary.progress,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.isPaid
                    ? 'ชำระครบแล้ว! 🎉'
                    : 'ชำระแล้ว ${(summary.progress * 100).round()}%',
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
                'จากยอดเริ่มต้น ${Money.format(summary.debt.initialAmountMinor)}',
                style: AppTypography.small,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        DebtSummaryRow(paid: summary.totalPaid, remaining: summary.remaining),
        if (summary.isPaid) ...[
          const SizedBox(height: 20),
          const FullyPaidMessage(),
        ],
      ],
    ),
  );
}
