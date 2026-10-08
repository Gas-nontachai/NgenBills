import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/app_confirm_sheet.dart';
import '../../domain/entities/borrowing.dart';
import '../providers/debt_providers.dart';

class BorrowingDetailSheet extends StatelessWidget {
  const BorrowingDetailSheet({super.key, required this.borrowing});
  final Borrowing borrowing;
  static Future<void> open(BuildContext context, Borrowing borrowing) async {
    final remove = await showAppSheet<bool>(
      context,
      BorrowingDetailSheet(borrowing: borrowing),
    );
    if (remove == true && context.mounted) {
      await showAppSheet<void>(
        context,
        DeleteBorrowingSheet(borrowing: borrowing),
        guarded: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: 'รายละเอียดการกู้เพิ่ม',
    onClose: () => Navigator.pop(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFD9EEF5),
            child: Icon(Icons.add, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          Money.format(borrowing.amountMinor, decimals: true),
          textAlign: TextAlign.center,
          style: AppTypography.display,
        ),
        const SizedBox(height: 8),
        Text(
          AppDates.format(borrowing.date),
          textAlign: TextAlign.center,
          style: AppTypography.small,
        ),
        if ((borrowing.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('หมายเหตุ', style: AppTypography.small),
          const SizedBox(height: 8),
          Text(borrowing.note!),
        ],
        const SizedBox(height: 32),
        AppButton(
          label: 'ลบรายการกู้เพิ่ม',
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
}

class DeleteBorrowingSheet extends ConsumerStatefulWidget {
  const DeleteBorrowingSheet({super.key, required this.borrowing});
  final Borrowing borrowing;
  @override
  ConsumerState<DeleteBorrowingSheet> createState() =>
      _DeleteBorrowingSheetState();
}

class _DeleteBorrowingSheetState extends ConsumerState<DeleteBorrowingSheet> {
  bool _saving = false;
  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      var existed = false;
      final saved = await ref.read(paymentActionProvider.notifier).run(
        () async {
          existed = await ref
              .read(borrowingRepositoryProvider)
              .delete(widget.borrowing.id);
        },
      );
      if (mounted && saved) {
        AppSnackBar.show(
          context,
          existed
              ? 'ลบรายการกู้เพิ่มแล้ว ยอดคงเหลืออัปเดตแล้ว'
              : 'รายการนี้ถูกลบไปแล้ว',
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
    child: AppConfirmSheet(
      title: 'ลบรายการกู้เพิ่ม',
      message: 'ยอดหนี้รวมและยอดคงเหลือจะลดลง\nลบได้เมื่อยอดหนี้รวมยังไม่น้อยกว่ายอดที่จ่ายแล้ว',
      confirmLabel: 'ลบรายการกู้เพิ่ม',
      isLoading: _saving,
      details: Column(
        children: [
          Text(
            Money.format(widget.borrowing.amountMinor),
            style: AppTypography.h1,
          ),
          Text(
            AppDates.format(widget.borrowing.date),
            style: AppTypography.small,
          ),
        ],
      ),
      onConfirm: ref.watch(paymentActionProvider) ? null : _delete,
      onCancel: () => Navigator.pop(context),
    ),
  );
}
