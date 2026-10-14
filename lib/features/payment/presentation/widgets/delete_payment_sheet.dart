import '../../../debt/domain/services/debt_wording.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/app_delete_sheet.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../debt/presentation/providers/debt_providers.dart';
import '../../domain/entities/payment.dart';

class DeletePaymentSheet extends ConsumerStatefulWidget {
  const DeletePaymentSheet({
    super.key,
    required this.payment,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  final Payment payment;
  static Future<void> open(
    BuildContext context,
    Payment payment, {
    DebtDirection direction = DebtDirection.payable,
  }) => showAppSheet<void>(
    context,
    DeletePaymentSheet(payment: payment, direction: direction),
    guarded: true,
  );
  @override
  ConsumerState<DeletePaymentSheet> createState() => _DeletePaymentSheetState();
}

class _DeletePaymentSheetState extends ConsumerState<DeletePaymentSheet> {
  DebtWording get wording => DebtWording(widget.direction);
  bool _saving = false;
  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      var existed = false;
      final saved = await ref.read(paymentActionProvider.notifier).run(
        () async {
          existed = await ref
              .read(paymentRepositoryProvider)
              .delete(widget.payment.id);
        },
      );
      if (mounted && saved) {
        AppSnackBar.show(
          context,
          existed ? wording.deletePaymentSaved : 'รายการนี้ถูกลบไปแล้ว',
        );
        setState(() => _saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDeleteSheet(
      title: wording.deletePayment,
      message: wording.deletePaymentExplanation(
        Money.format(widget.payment.amountMinor),
      ),
      warningTitle: 'ลบเฉพาะรายการนี้อย่างถาวร',
      warningMessage: 'รายการจะหายจากประวัติ และไม่สามารถกู้คืนได้',
      confirmLabel: wording.deletePayment,
      onConfirm: ref.watch(paymentActionProvider) ? null : _delete,
      onCancel: () => Navigator.pop(context),
      isLoading: _saving,
      details: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeleteDetailRow(
              label: wording.paymentAmount,
              value: Money.format(widget.payment.amountMinor),
              emphasis: true,
            ),
            const SizedBox(height: 12),
            DeleteDetailRow(
              label: wording.paymentDate,
              value: AppDates.format(widget.payment.date),
            ),
            if ((widget.payment.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('หมายเหตุ', style: AppTypography.small),
              Text(widget.payment.note!, style: AppTypography.body),
            ],
          ],
        ),
      ),
    ),
  );
}
