import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../formatters/currency_formatter.dart';
import '../../formatters/date_formatter.dart';

/// Shared presentation for payment and additional borrowing details.
class HistoryDetailContent extends StatelessWidget {
  const HistoryDetailContent({
    super.key,
    required this.amountMinor,
    required this.date,
    required this.isEdited,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.deleteLabel,
    required this.onEdit,
    required this.onDelete,
    this.note,
  });

  final int amountMinor;
  final DateTime date;
  final bool isEdited;
  final IconData icon;
  final Color iconColor, iconBackground;
  final String deleteLabel;
  final VoidCallback onEdit, onDelete;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Center(
        child: CircleAvatar(
          radius: 32,
          backgroundColor: iconBackground,
          child: Icon(icon, color: iconColor, size: 32),
        ),
      ),
      const SizedBox(height: 24),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          Money.format(amountMinor, decimals: true),
          textAlign: TextAlign.center,
          style: AppTypography.display.copyWith(
            fontSize: 36,
            color: AppColors.text,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        AppDates.format(date),
        textAlign: TextAlign.center,
        style: AppTypography.small,
      ),
      if (isEdited) ...[
        const SizedBox(height: 8),
        const Text(
          'แก้ไขแล้ว',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      ],
      if ((note ?? '').isNotEmpty) ...[
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('หมายเหตุ', style: AppTypography.caption),
              const SizedBox(height: 6),
              Text(note!, style: AppTypography.body),
            ],
          ),
        ),
      ],
      const SizedBox(height: 32),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final edit = _DetailAction(
            label: 'แก้ไขรายการ',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          );
          final delete = _DetailAction(
            label: deleteLabel,
            icon: Icons.delete_outline_rounded,
            destructive: true,
            onPressed: onDelete,
          );
          if (constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [edit, const SizedBox(height: 12), delete],
            );
          }
          return Row(
            children: [
              Expanded(child: edit),
              const SizedBox(width: 12),
              Expanded(child: delete),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: destructive ? AppColors.error : AppColors.text,
      backgroundColor: destructive ? AppColors.errorSoft : AppColors.background,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      side: destructive
          ? BorderSide.none
          : const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: AppTypography.small.copyWith(
        fontFamily: 'Kanit',
        fontWeight: FontWeight.w500,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}
