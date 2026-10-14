import '../../domain/services/debt_wording.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/inputs/app_amount_field.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/guarded_form_state.dart';
import '../../data/repositories/borrowing_repository.dart';
import '../../domain/services/debt_summary.dart';
import '../providers/debt_providers.dart';
import '../widgets/account_context_header.dart';

class AddBorrowingSheet extends ConsumerStatefulWidget {
  const AddBorrowingSheet({super.key, required this.summary});
  final DebtSummary summary;
  static Future<void> open(BuildContext context, DebtSummary summary) async {
    final navigator = Navigator.of(context);
    final receipt = await showModalBottomSheet<BorrowingReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => AddBorrowingSheet(summary: summary),
    );
    if (receipt != null && navigator.mounted) {
      await showAppSheet<void>(
        navigator.context,
        BorrowingSuccessSheet(
          receipt: receipt,
          direction: summary.debt.direction,
        ),
      );
    }
  }

  @override
  ConsumerState<AddBorrowingSheet> createState() => _AddBorrowingSheetState();
}

class _AddBorrowingSheetState extends GuardedFormState<AddBorrowingSheet> {
  DebtWording get wording => DebtWording(widget.summary.debt.direction);
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(), _note = TextEditingController();
  DateTime _today() {
    final now = ref.read(debtClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  late final _initialDate = _today();
  late DateTime _date = _initialDate;
  @override
  bool get dirty =>
      _amount.text.isNotEmpty || _note.text.isNotEmpty || _date != _initialDate;
  bool get _valid =>
      _validateAmount(_amount.text) == null && _note.text.length <= 500;
  String? _validateAmount(String? value) {
    final error = Money.validate(value);
    if (error != null) return error;
    if (Money.parse(value!)! > Money.maxMinor - widget.summary.totalDebt) {
      return wording.overflow;
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: _today(),
      helpText: wording.pickBorrowingDate,
      cancelText: 'ยกเลิก',
      confirmText: 'ยืนยัน',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (saving || confirming || !_form.currentState!.validate()) return;
    setState(() => saving = true);
    FocusScope.of(context).unfocus();
    try {
      BorrowingReceipt? receipt;
      final saved = await ref.read(paymentActionProvider.notifier).run(
        () async {
          receipt = await ref
              .read(borrowingRepositoryProvider)
              .add(
                debtId: widget.summary.debt.id,
                amountMinor: Money.parse(_amount.text)!,
                date: _date,
                note: _note.text,
              );
        },
      );
      if (saved) await finish(receipt);
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => guardedSheet(
    title: wording.borrowing,
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountContextHeader(
            debtId: widget.summary.debt.id,
            name: widget.summary.debt.name,
          ),
          AppCard(
            color: AppColors.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wording.currentOutstanding, style: AppTypography.small),
                Text(
                  Money.format(widget.summary.remaining),
                  style: AppTypography.h1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppAmountField(
            label: wording.borrowingAmount,
            controller: _amount,
            validator: _validateAmount,
            enabled: !saving,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text(wording.borrowingDate, style: AppTypography.body),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: saving ? null : _pickDate,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(AppDates.format(_date))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'หมายเหตุ (ไม่บังคับ)',
            controller: _note,
            maxLength: 500,
            showCharacterCounter: true,
            maxLines: 2,
            hint: wording.borrowingHint,
            enabled: !saving,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: wording.saveBorrowing,
            onPressed: _valid && !ref.watch(paymentActionProvider)
                ? _save
                : null,
            isLoading: saving,
          ),
        ],
      ),
    ),
  );
}

class BorrowingSuccessSheet extends StatelessWidget {
  const BorrowingSuccessSheet({
    super.key,
    required this.receipt,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
  final BorrowingReceipt receipt;
  @override
  Widget build(BuildContext context) => AppBottomSheet(
    onClose: () => Navigator.pop(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.check_circle_outline,
              size: 44,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          wording.borrowingSaved,
          style: AppTypography.h2,
          textAlign: TextAlign.center,
        ),
        Text(
          Money.format(receipt.amountMinor),
          style: AppTypography.h1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppCard(
          color: AppColors.primarySoft,
          child: Column(
            children: [
              Text(wording.newOutstanding, style: AppTypography.small),
              Text(Money.format(receipt.remaining), style: AppTypography.h1),
              Text(
                'จากเดิม ${Money.format(receipt.previousRemaining)}',
                style: AppTypography.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          wording.borrowingHistoryNotice,
          style: AppTypography.small,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(label: 'ตกลง', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}
