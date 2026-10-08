import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';

class DebtSummaryRow extends StatelessWidget {
  const DebtSummaryRow({
    super.key,
    required this.paid,
    required this.remaining,
  });
  final int paid, remaining;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _value('จ่ายแล้ว', paid)),
      const SizedBox(width: 16),
      Expanded(child: _value('คงเหลือ', remaining, end: true)),
    ],
  );
  Widget _value(String label, int amount, {bool end = false}) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.small),
      const SizedBox(height: 4),
      Text(Money.format(amount), style: AppTypography.title),
    ],
  );
}
