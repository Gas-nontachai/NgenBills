import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/inputs/app_amount_field.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';

class PaymentForm extends StatelessWidget {
  const PaymentForm({
    super.key,
    required this.formKey,
    required this.amount,
    required this.note,
    required this.remaining,
    required this.date,
    required this.onDate,
    required this.onChange,
    required this.onSave,
    required this.saving,
    required this.valid,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController amount, note;
  final int remaining;
  final DateTime date;
  final VoidCallback onDate, onChange, onSave;
  final bool saving, valid;
  void _increment(int value) {
    final next = ((Money.parse(amount.text) ?? 0) + value).clamp(0, remaining);
    amount.text = Money.input(next);
    amount.selection = TextSelection.collapsed(offset: amount.text.length);
    onChange();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ทุกยอดที่จ่าย คืออีกก้าวที่ใกล้เป้าหมาย',
          style: AppTypography.small,
        ),
        const SizedBox(height: 4),
        Text(
          'ยอดคงเหลือ ${Money.format(remaining)}',
          style: AppTypography.small.copyWith(color: AppColors.primaryDark),
        ),
        const SizedBox(height: 20),
        AppAmountField(
          controller: amount,
          remaining: remaining,
          autofocus: true,
          enabled: !saving,
          onChanged: (_) => onChange(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [50000, 100000, 500000]
              .map(
                (value) => ActionChip(
                  label: Text('+${Money.format(value).substring(1)}'),
                  backgroundColor: AppColors.primarySoft,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  onPressed: saving ? null : () => _increment(value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text('วันที่จ่าย', style: AppTypography.body),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: saving ? null : onDate,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: AppColors.text,
            minimumSize: const Size(48, 52),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(AppDates.format(date))),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 16),
          title: const Text(
            'เพิ่มหมายเหตุ (ไม่บังคับ)',
            style: AppTypography.small,
          ),
          children: [
            AppTextField(
              label: 'หมายเหตุ',
              controller: note,
              maxLength: 500,
              maxLines: 2,
              hint: 'เช่น จ่ายผ่านแอปธนาคาร',
              enabled: !saving,
              onChanged: (_) => onChange(),
              validator: (v) => (v?.length ?? 0) > 500
                  ? 'หมายเหตุต้องไม่เกิน 500 ตัวอักษร'
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'บันทึกการจ่าย',
          onPressed: valid ? onSave : null,
          isLoading: saving,
        ),
      ],
    ),
  );
}
