import '../../../debt/domain/services/debt_wording.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../debt/domain/services/debt_summary.dart';
import '../../../debt/presentation/sheets/edit_history_sheet.dart';
import '../../domain/entities/payment.dart';
import 'payment_detail_sheet.dart';
import 'delete_payment_sheet.dart';

class PaymentListItem extends StatelessWidget {
  const PaymentListItem({
    super.key,
    required this.payment,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
  final Payment payment;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            PaymentDetailSheet.open(context, payment, direction: direction),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                radius: 23,
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            wording.paymentHistory,
                            style: AppTypography.body,
                          ),
                        ),
                        if (payment.isEdited) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'แก้ไขแล้ว',
                            excludeFromSemantics: true,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppColors.secondary,
                              semanticLabel: 'แก้ไขแล้ว',
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      AppDates.format(payment.date),
                      style: AppTypography.caption,
                    ),
                    if ((payment.note ?? '').isNotEmpty)
                      Text(
                        payment.note!,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '-${Money.format(payment.amountMinor)}',
                  style: AppTypography.title.copyWith(
                    color: AppColors.primaryDark,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: wording.paymentMenu,
                icon: const Icon(Icons.more_vert_rounded, size: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'details':
                      PaymentDetailSheet.open(
                        context,
                        payment,
                        direction: direction,
                      );
                    case 'edit':
                      EditHistorySheet.open(
                        context,
                        DebtHistoryEntry(payment: payment),
                        direction: direction,
                      );
                    case 'delete':
                      DeletePaymentSheet.open(
                        context,
                        payment,
                        direction: direction,
                      );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined),
                        SizedBox(width: 12),
                        Text('ดูรายละเอียด'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('แก้ไขรายการ'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 12),
                        Text(
                          wording.deletePayment,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
