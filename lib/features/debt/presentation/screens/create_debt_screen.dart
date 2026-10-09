import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class CreateDebtScreen extends ConsumerStatefulWidget {
  const CreateDebtScreen({super.key});
  @override
  ConsumerState<CreateDebtScreen> createState() => _CreateDebtScreenState();
}

class _CreateDebtScreenState extends ConsumerState<CreateDebtScreen> {
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
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
        context.go('/');
        if (onboardingDone) {
          AppSnackBar.show(context, 'เริ่มต้นได้ดีแล้ว มาค่อย ๆ ไปด้วยกัน 🌱');
        }
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(paymentActionProvider);
    final additional = ref.watch(accountsProvider).value?.isNotEmpty == true;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            additional ? 'เพิ่มบัญชีหนี้' : 'เพิ่มหนี้ก้อนแรก',
            style: AppTypography.h2,
          ),
          leading: IconButton(
            tooltip: 'กลับ',
            onPressed: busy ? null : () => context.go('/'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
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
                                  Text(
                                    'เริ่มต้นทีละก้าว',
                                    style: AppTypography.title,
                                  ),
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
                        enabled: !busy,
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
                        enabled: !busy,
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        label: 'หมายเหตุ (ไม่บังคับ)',
                        controller: _note,
                        maxLength: 500,
                        maxLines: 3,
                        hint: 'เช่น ธนาคาร เลขบัญชี หรือรายละเอียดเพิ่มเติม',
                        enabled: !busy,
                        validator: (v) => (v?.length ?? 0) > 500
                            ? 'หมายเหตุต้องไม่เกิน 500 ตัวอักษร'
                            : null,
                      ),
                      const SizedBox(height: 40),
                      AppButton(
                        label: additional
                            ? 'สร้างบัญชีหนี้'
                            : 'สร้างหนี้ก้อนแรก',
                        onPressed: _save,
                        isLoading: busy,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
