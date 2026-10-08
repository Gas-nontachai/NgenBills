import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../domain/entities/payment.dart';
import 'delete_payment_sheet.dart';

class PaymentDetailSheet extends StatelessWidget {
  const PaymentDetailSheet({super.key, required this.payment});
  final Payment payment;
  static Future<void> open(BuildContext context, Payment payment) async {
    final remove = await showAppSheet<bool>(
      context,
      PaymentDetailSheet(payment: payment),
    );
    if (remove == true && context.mounted) {
      await DeletePaymentSheet.open(context, payment);
    }
  }

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: 'รายละเอียดการจ่าย',
    onClose: () => Navigator.pop(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.arrow_upward_rounded,
              color: AppColors.primaryDark,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          Money.format(payment.amountMinor, decimals: true),
          textAlign: TextAlign.center,
          style: AppTypography.display,
        ),
        const SizedBox(height: 8),
        Text(
          AppDates.format(payment.date),
          textAlign: TextAlign.center,
          style: AppTypography.small,
        ),
        if ((payment.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('หมายเหตุ', style: AppTypography.small),
          const SizedBox(height: 8),
          Text(payment.note!),
        ],
        const SizedBox(height: 32),
        AppButton(
          label: 'ลบรายการจ่าย',
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
}
