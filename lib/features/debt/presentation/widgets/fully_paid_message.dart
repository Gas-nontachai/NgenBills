import '../../domain/services/debt_wording.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/sprout_illustration.dart';

class FullyPaidMessage extends StatelessWidget {
  const FullyPaidMessage({super.key, this.direction = DebtDirection.payable});
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.primarySoft,
    padding: EdgeInsets.all(16),
    child: Row(
      children: [
        SproutIllustration(size: 64),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(wording.congratTitle, style: AppTypography.title),
              SizedBox(height: 4),
              Text(wording.congratBody, style: AppTypography.small),
            ],
          ),
        ),
      ],
    ),
  );
}
