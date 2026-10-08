import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/sheets/guarded_form_state.dart';
import '../../domain/entities/account_appearance.dart';
import '../../domain/entities/debt.dart';
import '../providers/debt_providers.dart';
import '../widgets/account_avatar.dart';
import 'delete_debt_sheet.dart';

class CustomizeAccountSheet extends ConsumerStatefulWidget {
  const CustomizeAccountSheet({super.key, required this.debt});
  final Debt debt;
  static Future<void> open(BuildContext context, Debt debt) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        builder: (_) => CustomizeAccountSheet(debt: debt),
      );
  @override
  ConsumerState<CustomizeAccountSheet> createState() =>
      _CustomizeAccountSheetState();
}

class _CustomizeAccountSheetState
    extends GuardedFormState<CustomizeAccountSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.debt.name);
  late String _icon = AccountAppearance.iconKeys.contains(widget.debt.iconKey)
      ? widget.debt.iconKey
      : 'wallet';
  late String _color =
      AccountAppearance.colorKeys.contains(widget.debt.colorKey)
      ? widget.debt.colorKey
      : 'green';
  @override
  bool get dirty =>
      _name.text != widget.debt.name ||
      _icon != widget.debt.iconKey ||
      _color != widget.debt.colorKey;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving || confirming || !_form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final saved = await ref
          .read(paymentActionProvider.notifier)
          .run(
            () => ref
                .read(debtRepositoryProvider)
                .customize(
                  debtId: widget.debt.id,
                  name: _name.text,
                  iconKey: _icon,
                  colorKey: _color,
                ),
          );
      if (saved && mounted) {
        AppSnackBar.show(context, 'บันทึกการปรับแต่งบัญชีแล้ว');
        await finish();
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete() async {
    if (saving || confirming) return;
    confirming = true;
    final deleted = await DeleteDebtSheet.open(context, widget.debt);
    confirming = false;
    if (deleted == true) await finish();
  }

  @override
  Widget build(BuildContext context) {
    final busy = saving || ref.watch(paymentActionProvider);
    return guardedSheet(
      title: 'ปรับแต่งบัญชี',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AccountAvatar(iconKey: _icon, colorKey: _color, size: 76),
            ),
            const SizedBox(height: 12),
            Text(
              _name.text.trim().isEmpty ? 'ชื่อบัญชี' : _name.text.trim(),
              textAlign: TextAlign.center,
              style: AppTypography.title,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'ชื่อบัญชี',
              controller: _name,
              maxLength: 100,
              enabled: !busy,
              onChanged: (_) {
                setState(() {});
                _form.currentState?.validate();
              },
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'กรุณากรอกชื่อบัญชี'
                  : (v!.trim().length > 100
                        ? 'ชื่อบัญชีต้องไม่เกิน 100 ตัวอักษร'
                        : null),
            ),
            const SizedBox(height: 16),
            const Text('เลือกไอคอน', style: AppTypography.body),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AccountAppearance.iconKeys
                  .map(
                    (key) => Semantics(
                      selected: key == _icon,
                      child: Tooltip(
                        message: AccountVisuals.iconLabel(key),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: key == _icon
                                ? AppColors.primarySoft
                                : null,
                            side: BorderSide(
                              color: key == _icon
                                  ? AppColors.primaryDark
                                  : AppColors.border,
                            ),
                          ),
                          onPressed: busy
                              ? null
                              : () => setState(() => _icon = key),
                          child: Icon(
                            AccountVisuals.icons[key],
                            semanticLabel: AccountVisuals.iconLabel(key),
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('เลือกสี', style: AppTypography.body),
            const SizedBox(height: 8),
            Wrap(
              spacing: 0,
              runSpacing: 4,
              children: AccountAppearance.colorKeys
                  .map(
                    (key) => Semantics(
                      selected: key == _color,
                      child: Tooltip(
                        message: AccountVisuals.colorLabel(key),
                        child: IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 48,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: busy
                              ? null
                              : () => setState(() => _color = key),
                          icon: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AccountVisuals.colors[key],
                              border: key == _color
                                  ? Border.all(
                                      color: AppColors.primaryDark,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: key == _color
                                ? const Icon(
                                    Icons.check,
                                    size: 22,
                                    color: AppColors.primaryDark,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'บันทึก',
              onPressed: dirty && _name.text.trim().isNotEmpty && !busy
                  ? _save
                  : null,
              isLoading: saving,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('ลบบัญชีนี้'),
                onPressed: busy ? null : _delete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
