import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/payment.dart';
import 'payment_detail_sheet.dart';
import 'delete_payment_sheet.dart';

class PaymentListItem extends StatelessWidget {
  const PaymentListItem({super.key, required this.payment});
  final Payment payment;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => PaymentDetailSheet.open(context, payment),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                radius: 23,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ชำระหนี้', style: AppTypography.body),
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
                  Money.format(payment.amountMinor),
                  style: AppTypography.title.copyWith(
                    color: AppColors.primaryDark,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'เมนูรายการจ่าย',
                icon: const Icon(Icons.more_vert_rounded, size: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) => value == 'delete'
                    ? DeletePaymentSheet.open(context, payment)
                    : PaymentDetailSheet.open(context, payment),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined),
                        SizedBox(width: 12),
                        Text('ดูรายละเอียด'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'ลบรายการจ่าย',
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
