import '../../../debt/domain/services/debt_wording.dart';

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
    this.direction = DebtDirection.payable,
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
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
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
        Text(wording.paymentHelp, style: AppTypography.small),
        const SizedBox(height: 4),
        Text(
          '${wording.remainingAmount} ${Money.format(remaining)}',
          style: AppTypography.small.copyWith(color: AppColors.primaryDark),
        ),
        const SizedBox(height: 20),
        AppAmountField(
          controller: amount,
          remaining: remaining,
          validator: (value) {
            final error = Money.validate(value, remaining: remaining);
            return error != null && (Money.parse(value ?? '') ?? 0) > remaining
                ? wording.overRemaining(Money.format(remaining))
                : error;
          },
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
        Text(wording.paymentDate, style: AppTypography.body),
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
          title: Text('เพิ่มหมายเหตุ (ไม่บังคับ)', style: AppTypography.small),
          children: [
            AppTextField(
              label: 'หมายเหตุ',
              controller: note,
              maxLength: 500,
              showCharacterCounter: true,
              maxLines: 2,
              hint: wording.paymentHint,
              enabled: !saving,
              onChanged: (_) => onChange(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppButton(
          label: wording.savePayment,
          onPressed: valid ? onSave : null,
          isLoading: saving,
        ),
      ],
    ),
  );
}
