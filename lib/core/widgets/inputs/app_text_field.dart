import 'package:flutter/material.dart';

import '../../../app/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
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
        enabled: enabled,
        maxLength: maxLength,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint, counterText: ''),
        textInputAction: maxLines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
      ),
    ],
  );
}
