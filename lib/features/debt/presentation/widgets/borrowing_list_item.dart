import '../../../../app/theme/app_colors.dart';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../domain/entities/borrowing.dart';
import '../sheets/borrowing_detail_sheet.dart';

class BorrowingListItem extends StatelessWidget {
  const BorrowingListItem({super.key, required this.borrowing});
  final Borrowing borrowing;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => BorrowingDetailSheet.open(context, borrowing),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFD9EEF5),
                radius: 23,
                child: Icon(Icons.add_rounded, color: Color(0xFF2673C7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text('กู้เพิ่ม', style: AppTypography.body),
                        ),
                        if (borrowing.isEdited) ...[
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
                      AppDates.format(borrowing.date),
                      style: AppTypography.caption,
                    ),
                    if ((borrowing.note ?? '').isNotEmpty)
                      Text(
                        borrowing.note!,
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
                  '+${Money.format(borrowing.amountMinor)}',
                  style: AppTypography.title.copyWith(
                    color: const Color(0xFF2673C7),
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}
