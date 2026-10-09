import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/app_confirm_sheet.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../debt/domain/services/debt_summary.dart';
import '../../../debt/presentation/providers/debt_providers.dart';
import 'payment_form.dart';
import '../../../debt/presentation/widgets/account_context_header.dart';

class AddPaymentSheet extends ConsumerStatefulWidget {
  const AddPaymentSheet({super.key, required this.summary});
  final DebtSummary summary;
  static Future<void> open(
    BuildContext context,
    DebtSummary summary,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Native drag dismissal uses Navigator.pop and bypasses PopScope. Handle
    // the drag gesture ourselves so unsaved data and pending writes are safe.
    enableDrag: false,
    builder: (_) => AddPaymentSheet(summary: summary),
  );
  @override
  ConsumerState<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<AddPaymentSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(), _note = TextEditingController();
  late final DateTime _initialDate = AppDates.today();
  late DateTime _date = _initialDate;
  bool _saving = false, _allowClose = false, _confirming = false;
  bool get _dirty =>
      _amount.text.isNotEmpty || _note.text.isNotEmpty || _date != _initialDate;
  bool get _valid =>
      Money.validate(_amount.text, remaining: widget.summary.remaining) ==
          null &&
      _note.text.length <= 500;
  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _confirming) return;
    if (_dirty) {
      _confirming = true;
      final discard = await showAppSheet<bool>(
        context,
        Builder(
          builder: (dialogContext) => AppConfirmSheet(
            title: 'ละทิ้งข้อมูลที่กรอกไว้?',
            message: 'รายการนี้ยังไม่ได้บันทึก คุณกลับไปกรอกต่อได้',
            confirmLabel: 'ละทิ้งข้อมูล',
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      );
      _confirming = false;
      if (discard != true || !mounted) return;
    }
    await _pop();
  }

  Future<void> _pop() async {
    if (!mounted) return;
    setState(() => _allowClose = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: AppDates.today(),
      helpText: 'เลือกวันที่จ่าย',
      cancelText: 'ยกเลิก',
      confirmText: 'ยืนยัน',
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();
    try {
      final saved = await ref
          .read(paymentActionProvider.notifier)
          .run(
            () => ref
                .read(paymentRepositoryProvider)
                .add(
                  debtId: widget.summary.debt.id,
                  amountMinor: Money.parse(_amount.text)!,
                  date: _date,
                  note: _note.text,
                ),
          );
      if (mounted && saved) {
        AppSnackBar.show(
          context,
          'บันทึกการจ่ายแล้ว อีกก้าวที่ใกล้เป้าหมาย 🌱',
        );
        await _pop();
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowClose,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: AppBottomSheet(
      title: 'บันทึกการจ่าย',
      onClose: _saving ? null : _close,
      onDragClose: _close,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AccountContextHeader(
            debtId: widget.summary.debt.id,
            name: widget.summary.debt.name,
          ),
          PaymentForm(
            formKey: _form,
            amount: _amount,
            note: _note,
            remaining: widget.summary.remaining,
            date: _date,
            onDate: _pickDate,
            onChange: () => setState(() {}),
            onSave: _save,
            saving: _saving,
            valid: _valid,
          ),
        ],
      ),
    ),
  );
}
