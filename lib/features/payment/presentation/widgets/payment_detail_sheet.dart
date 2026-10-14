import '../../../debt/domain/services/debt_wording.dart';
import '../../../../core/widgets/sheets/history_detail_content.dart';
import '../../../debt/domain/services/debt_summary.dart';
import '../../../debt/presentation/sheets/edit_history_sheet.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../domain/entities/payment.dart';
import 'delete_payment_sheet.dart';

class PaymentDetailSheet extends StatelessWidget {
  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
  final Payment payment;
  static Future<void> open(
    BuildContext context,
    Payment payment, {
    DebtDirection direction = DebtDirection.payable,
  }) async {
    final action = await showAppSheet<String>(
      context,
      PaymentDetailSheet(payment: payment, direction: direction),
    );
    if (action == 'edit' && context.mounted) {
      await EditHistorySheet.open(
        context,
        DebtHistoryEntry(payment: payment),
        direction: direction,
      );
    } else if (action == 'delete' && context.mounted) {
      await DeletePaymentSheet.open(context, payment, direction: direction);
    }
  }

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: wording.paymentDetail,
    onClose: () => Navigator.pop(context),
    child: HistoryDetailContent(
      amountMinor: payment.amountMinor,
      date: payment.date,
      note: payment.note,
      isEdited: payment.isEdited,
      icon: Icons.arrow_upward_rounded,
      iconColor: AppColors.primaryDark,
      iconBackground: AppColors.primarySoft,
      deleteLabel: wording.deletePayment,
      onEdit: () => Navigator.pop(context, 'edit'),
      onDelete: () => Navigator.pop(context, 'delete'),
    ),
  );
}
