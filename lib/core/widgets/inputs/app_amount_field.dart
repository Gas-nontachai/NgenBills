import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_typography.dart';
import '../../formatters/currency_formatter.dart';

class AppAmountField extends StatelessWidget {
  const AppAmountField({
    super.key,
    required this.controller,
    this.label = 'จำนวนเงิน (บาท)',
    this.remaining,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final int? remaining;
  final bool autofocus, enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        autofocus: autofocus,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        inputFormatters: [
          TextInputFormatter.withFunction(
            (oldValue, newValue) =>
                RegExp(r'^\d{0,12}(\.\d{0,2})?$').hasMatch(newValue.text)
                ? newValue
                : oldValue,
          ),
        ],
        style: AppTypography.h2,
        decoration: const InputDecoration(hintText: '0.00'),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator:
            validator ?? (value) => Money.validate(value, remaining: remaining),
        onChanged: onChanged,
      ),
    ],
  );
}
