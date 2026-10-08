import 'package:flutter/material.dart';

import '../buttons/app_button.dart';
import 'app_bottom_sheet.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class AppConfirmSheet extends StatelessWidget {
  const AppConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.isLoading = false,
    this.destructive = true,
    this.details,
  });
  final String title, message, confirmLabel;
  final VoidCallback? onConfirm, onCancel;
  final bool isLoading, destructive;
  final Widget? details;
  @override
  Widget build(BuildContext context) => AppBottomSheet(
    child: Column(
      children: [
        const SizedBox(height: 14),
        CircleAvatar(
          radius: 28,
          backgroundColor: destructive
              ? AppColors.errorSoft
              : AppColors.primarySoft,
          child: Icon(
            destructive
                ? Icons.delete_outline_rounded
                : Icons.edit_note_rounded,
            color: destructive ? AppColors.error : AppColors.primaryDark,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: AppTypography.small, textAlign: TextAlign.center),
        if (details != null) ...[const SizedBox(height: 16), details!],
        const SizedBox(height: 24),
        AppButton(
          label: confirmLabel,
          onPressed: onConfirm,
          isLoading: isLoading,
          variant: destructive
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'ยกเลิก',
          onPressed: isLoading ? null : onCancel,
          variant: AppButtonVariant.secondary,
        ),
      ],
    ),
  );
}
