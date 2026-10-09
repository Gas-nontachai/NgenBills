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
      _name.text.isNotEmpty || _amount.text.isNotEmpty || _note.text.isNotEmpty;

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
              );
        },
      );
      if (mounted && saved) {
        ref.read(selectedDebtIdProvider.notifier).select(createdId);
        final onboardingDone =
            ref.read(reminderControllerProvider).onboardingDone == true;
        if (onboardingDone) {
          AppSnackBar.show(context, 'เริ่มต้นได้ดีแล้ว มาค่อย ๆ ไปด้วยกัน 🌱');
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
      title: additional ? 'เพิ่มบัญชีหนี้' : 'เพิ่มหนี้ก้อนแรก',
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppCard(
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
                        Text(
                          'แค่รู้ว่าเรามีหนี้เท่าไหร่\nก็เป็นจุดเริ่มต้นที่ดีแล้ว',
                          style: AppTypography.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AppTextField(
              label: 'ชื่อหนี้',
              controller: _name,
              hint: 'เช่น บัตรเครดิต',
              maxLength: 100,
              enabled: !saving && !busy,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'กรุณากรอกชื่อหนี้'
                  : (value!.trim().length > 100
                        ? 'ชื่อหนี้ต้องไม่เกิน 100 ตัวอักษร'
                        : null),
            ),
            const SizedBox(height: 20),
            AppAmountField(
              label: 'ยอดหนี้ตั้งต้น (บาท)',
              controller: _amount,
              enabled: !saving && !busy,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'หมายเหตุ (ไม่บังคับ)',
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              hint: 'เช่น ธนาคาร เลขบัญชี หรือรายละเอียดเพิ่มเติม',
              enabled: !saving && !busy,
              validator: (v) => (v?.length ?? 0) > 500
                  ? 'หมายเหตุต้องไม่เกิน 500 ตัวอักษร'
                  : null,
            ),
            const SizedBox(height: 40),
            AppButton(
              label: additional ? 'สร้างบัญชีหนี้' : 'สร้างหนี้ก้อนแรก',
              onPressed: busy ? null : _save,
              isLoading: saving,
            ),
            const SizedBox(height: 20),
            const Text(
              'ค่อย ๆ จ่าย ค่อย ๆ ไป ถึงเป้าหมายได้เหมือนกัน',
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ),
      ),
    );
  }
}
