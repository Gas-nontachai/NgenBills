import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.receipt_long_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 44, color: AppColors.primary.withValues(alpha: .5)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message, style: AppTypography.small, textAlign: TextAlign.center),
      ],
    ),
  );
}
