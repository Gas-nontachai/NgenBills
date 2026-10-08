import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/sprout_illustration.dart';

class FullyPaidMessage extends StatelessWidget {
  const FullyPaidMessage({super.key});
  @override
  Widget build(BuildContext context) => const AppCard(
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
              Text('เก่งมากเลย! 🌱', style: AppTypography.title),
              SizedBox(height: 4),
              Text(
                'คุณก้าวมาถึงเป้าหมายแล้ว\nขอบคุณที่ดูแลตัวเองนะ',
                style: AppTypography.small,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
