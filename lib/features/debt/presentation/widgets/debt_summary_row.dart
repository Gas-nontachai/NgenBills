import '../../domain/services/debt_wording.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/formatters/currency_formatter.dart';

class DebtSummaryRow extends StatelessWidget {
  const DebtSummaryRow({
    super.key,
    this.direction = DebtDirection.payable,
    required this.paid,
    required this.remaining,
  });
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
  final int paid, remaining;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _value(wording.paid, paid)),
      Container(width: 1, height: 36, color: AppColors.border),
      Expanded(child: _value(wording.remaining, remaining, end: true)),
    ],
  );
  Widget _value(String label, int amount, {bool end = false}) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.small),
      const SizedBox(height: 4),
      Text(
        Money.format(amount),
        style: AppTypography.title.copyWith(
          color: end ? AppColors.text : AppColors.primaryDark,
        ),
      ),
    ],
  );
}
