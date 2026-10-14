import '../../domain/services/debt_wording.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/inputs/app_amount_field.dart';
import '../../../../core/widgets/inputs/app_text_field.dart';
import '../../../../core/widgets/sheets/guarded_form_state.dart';
import '../../domain/services/debt_summary.dart';
import '../providers/debt_providers.dart';
import '../widgets/account_context_header.dart';

/// Loads the target account afresh; the repository rechecks all limits on save.
class EditHistorySheet extends ConsumerStatefulWidget {
  const EditHistorySheet({
    super.key,
    required this.entry,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  final DebtHistoryEntry entry;

  static Future<void> open(
    BuildContext context,
    DebtHistoryEntry entry, {
    DebtDirection direction = DebtDirection.payable,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    builder: (_) => EditHistorySheet(entry: entry, direction: direction),
  );

  @override
  ConsumerState<EditHistorySheet> createState() => _EditHistorySheetState();
}

class _EditHistorySheetState extends GuardedFormState<EditHistorySheet> {
  late DebtDirection _direction = widget.direction;
  DebtWording get wording => DebtWording(_direction);
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(), _note = TextEditingController();
  late DateTime _date;
  late Future<DebtSummary> _summary;
  DebtHistoryEntry? _original;

  bool get _payment => widget.entry.payment != null;
  String get _debtId =>
      widget.entry.payment?.debtId ?? widget.entry.borrowing!.debtId;
  int _value(DebtHistoryEntry entry) =>
      entry.payment?.amountMinor ?? entry.borrowing!.amountMinor;
  String _memo(DebtHistoryEntry entry) =>
      entry.payment?.note ?? entry.borrowing?.note ?? '';

  @override
  void initState() {
    super.initState();
    _date = widget.entry.date;
    _summary = _load();
  }

  Future<DebtSummary> _load() async {
    final summary = await ref.read(debtRepositoryProvider).load(_debtId);
    if (summary == null) throw const AppException('ไม่พบบัญชีนี้');
    final matches = summary.history.where(
      (e) => e.id == widget.entry.id && (e.payment != null) == _payment,
    );
    if (matches.isEmpty) {
      throw const AppException('ไม่พบรายการนี้ อาจถูกลบไปแล้ว');
    }
    if (mounted && _direction != summary.debt.direction) {
      setState(() => _direction = summary.debt.direction);
    }
    _original = matches.single;
    if (!mounted) return summary;
    _amount.text = Money.input(_value(_original!));
    _note.text = _memo(_original!);
    _date = _original!.date;
    return summary;
  }

  @override
  bool get dirty =>
      _original != null &&
      (Money.parse(_amount.text) != _value(_original!) ||
          AppDates.storage(_date) != AppDates.storage(_original!.date) ||
          _note.text.trim() != _memo(_original!).trim());

  String? _validateAmount(String? input, DebtSummary summary) {
    final error = Money.validate(input);
    if (error != null) return error;
    final amount = Money.parse(input!)!;
    if (_payment) {
      final limit = summary.remaining + _value(_original!);
      if (amount > limit) {
        return 'จำนวนเงินเกินยอดที่แก้ไขได้ ${Money.format(limit)}';
      }
    } else {
      final total = summary.totalDebt - _value(_original!) + amount;
      if (total > Money.maxMinor) return wording.overflow;
      if (total < summary.totalPaid) {
        return wording.belowPaid;
      }
    }
    return null;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: AppDates.today(),
      helpText: _payment ? wording.pickPaymentDate : wording.pickBorrowingDate,
      cancelText: 'ยกเลิก',
      confirmText: 'ยืนยัน',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (saving || confirming || !dirty || !_form.currentState!.validate()) {
      return;
    }
    setState(() => saving = true);
    FocusScope.of(context).unfocus();
    try {
      final saved = await ref.read(paymentActionProvider.notifier).run(() {
        if (_payment) {
          return ref
              .read(paymentRepositoryProvider)
              .update(
                id: widget.entry.id,
                amountMinor: Money.parse(_amount.text)!,
                date: _date,
                note: _note.text,
              );
        }
        return ref
            .read(borrowingRepositoryProvider)
            .update(
              id: widget.entry.id,
              amountMinor: Money.parse(_amount.text)!,
              date: _date,
              note: _note.text,
            );
      });
      if (mounted && saved) {
        AppSnackBar.show(context, wording.editSaved);
        await finish();
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => guardedSheet(
    title: _payment ? wording.editPayment : wording.editBorrowing,
    child: FutureBuilder<DebtSummary>(
      future: _summary,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              Text('โหลดรายการไม่สำเร็จ'),
              Text(
                snapshot.error is AppException
                    ? (snapshot.error as AppException).message
                    : 'กรุณาลองใหม่อีกครั้ง',
              ),
              TextButton(
                onPressed: () => setState(() => _summary = _load()),
                child: Text('ลองใหม่'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final summary = snapshot.data!;
        final valid =
            dirty &&
            _validateAmount(_amount.text, summary) == null &&
            _note.text.length <= 500;
        return Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AccountContextHeader(debtId: _debtId, name: summary.debt.name),
              AppAmountField(
                label: _payment
                    ? wording.paymentAmountBaht
                    : wording.borrowingAmount,
                controller: _amount,
                validator: (v) => _validateAmount(v, summary),
                enabled: !saving,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Text(
                _payment ? wording.paymentDate : wording.borrowingDate,
                style: AppTypography.body,
              ),
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
                enabled: !saving,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'บันทึกการแก้ไข',
                onPressed: valid && !ref.watch(paymentActionProvider)
                    ? _save
                    : null,
                isLoading: saving,
              ),
            ],
          ),
        );
      },
    ),
  );
}
