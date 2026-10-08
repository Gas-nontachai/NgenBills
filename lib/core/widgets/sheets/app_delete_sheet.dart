import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../buttons/app_button.dart';
import 'app_bottom_sheet.dart';

/// Destructive actions state the target, impact and permanence before the CTA.
class AppDeleteSheet extends StatelessWidget {
  const AppDeleteSheet({
    super.key,
    required this.title,
    required this.message,
    required this.details,
    required this.warningTitle,
    required this.warningMessage,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.warningItems = const [],
    this.accountDeletion = false,
    this.isLoading = false,
  });
  final String title, message, warningTitle, warningMessage, confirmLabel;
  final Widget details;
  final List<String> warningItems;
  final bool accountDeletion, isLoading;
  final VoidCallback? onConfirm, onCancel;

  @override
  Widget build(BuildContext context) {
    final warningColor = accountDeletion
        ? AppColors.dueUrgent
        : AppColors.dueSoon;
    return AppBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTypography.h1)),
              IconButton(
                tooltip: 'ปิด',
                onPressed: isLoading ? null : onCancel,
                icon: const Icon(Icons.close, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.small.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 20),
          details,
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accountDeletion
                  ? AppColors.errorSoft
                  : const Color(0xFFFFF6DF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: warningColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warningTitle,
                        style: AppTypography.small.copyWith(
                          color: warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        warningMessage,
                        style: AppTypography.small.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                      if (warningItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...warningItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 7),
                                  child: Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: AppTypography.small.copyWith(
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: confirmLabel,
            onPressed: onConfirm,
            isLoading: isLoading,
            variant: AppButtonVariant.destructive,
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
}

class DeleteDetailRow extends StatelessWidget {
  const DeleteDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label, value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelWidget = Text(label, style: AppTypography.small);
      final valueWidget = Text(
        value,
        textAlign: TextAlign.end,
        style: emphasis ? AppTypography.title : AppTypography.body,
      );
      if (constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(14) > 20) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelWidget, const SizedBox(height: 4), valueWidget],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: labelWidget),
          const SizedBox(width: 12),
          Expanded(child: valueWidget),
        ],
      );
    },
  );
}
