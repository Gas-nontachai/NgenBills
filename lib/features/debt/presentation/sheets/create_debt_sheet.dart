import '../../domain/services/debt_wording.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/inputs/app_amount_field.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/sprout_illustration.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_direction_chip.dart';
import '../../../reminders/presentation/reminder_providers.dart';

import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/guarded_form_state.dart';

class CreateDebtSheet extends ConsumerStatefulWidget {
  const CreateDebtSheet({super.key, this.additional = true});
  final bool additional;

  static Future<void> open(
    BuildContext context, {
    bool additional = true,
  }) async {
    await showAppSheet<String>(
      context,
      CreateDebtSheet(additional: additional),
      guarded: true,
    );
  }

  @override
  ConsumerState<CreateDebtSheet> createState() => _CreateDebtSheetState();
}

class _CreateDebtSheetState extends GuardedFormState<CreateDebtSheet> {
  DebtDirection _direction = DebtDirection.payable;
  DebtWording get wording => DebtWording(_direction);
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _amount = TextEditingController(),
      _note = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  bool get dirty =>
      _name.text.isNotEmpty ||
      _amount.text.isNotEmpty ||
      _note.text.isNotEmpty ||
      _direction != DebtDirection.payable;

  Future<void> _save() async {
    if (saving || confirming || !_form.currentState!.validate()) return;
    setState(() => saving = true);
    FocusScope.of(context).unfocus();
    try {
      String? createdId;
      final saved = await ref.read(paymentActionProvider.notifier).run(
        () async {
          createdId = await ref
              .read(debtRepositoryProvider)
              .create(
                name: _name.text,
                amountMinor: Money.parse(_amount.text)!,
                note: _note.text,
                direction: _direction,
              );
        },
      );
      if (mounted && saved) {
        ref.read(selectedDebtIdProvider.notifier).select(createdId);
        final onboardingDone =
            ref.read(reminderControllerProvider).onboardingDone == true;
        if (onboardingDone) {
          AppSnackBar.show(context, wording.createSaved);
        }
        await finish(createdId);
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(paymentActionProvider);
    final additional = widget.additional;
    return guardedSheet(
      title: additional ? wording.createTitle : wording.createFirstTitle,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: AppColors.primarySoft,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SproutIllustration(size: 66),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('เริ่มต้นทีละก้าว', style: AppTypography.title),
                        SizedBox(height: 4),
                        Text(wording.createHelp, style: AppTypography.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            DebtDirectionToggle(
              value: _direction,
              onChanged: saving || busy
                  ? null
                  : (value) => setState(() => _direction = value),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: wording.accountName,
              controller: _name,
              hint: wording.createHint,
              maxLength: 100,
              enabled: !saving && !busy,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? wording.nameRequired
                  : (value!.trim().length > 100 ? wording.nameTooLong : null),
            ),
            const SizedBox(height: 20),
            AppAmountField(
              label: wording.initialAmount,
              controller: _amount,
              enabled: !saving && !busy,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'หมายเหตุ (ไม่บังคับ)',
              controller: _note,
              maxLength: 500,
              showCharacterCounter: true,
              maxLines: 3,
              hint: 'เช่น ธนาคาร เลขบัญชี หรือรายละเอียดเพิ่มเติม',
              enabled: !saving && !busy,
            ),
            const SizedBox(height: 40),
            AppButton(
              label: additional ? wording.createSave : wording.createFirstSave,
              onPressed: busy ? null : _save,
              isLoading: saving,
            ),
            const SizedBox(height: 20),
            Text(
              wording.createFooter,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
