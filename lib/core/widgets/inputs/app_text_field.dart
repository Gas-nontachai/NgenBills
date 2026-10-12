import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.maxLength,
    this.showCharacterCounter = false,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final FormFieldValidator<String>? validator;
  final int? maxLength;
  final bool showCharacterCounter;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          if (showCharacterCounter && maxLength != null) ...[
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final length = value.text.characters.length;
                return Text(
                  '$length/$maxLength',
                  style: AppTypography.small.copyWith(
                    color: length >= maxLength!
                        ? AppColors.error
                        : AppColors.secondary.withValues(alpha: 0.65),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        enabled: enabled,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
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
