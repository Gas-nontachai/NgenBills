import '../../../../core/widgets/sheets/history_detail_content.dart';
import '../../domain/services/debt_summary.dart';
import 'edit_history_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/app_confirm_sheet.dart';
import '../../domain/entities/borrowing.dart';
import '../providers/debt_providers.dart';

class BorrowingDetailSheet extends StatelessWidget {
  const BorrowingDetailSheet({super.key, required this.borrowing});
  final Borrowing borrowing;
  static Future<void> open(BuildContext context, Borrowing borrowing) async {
    final action = await showAppSheet<String>(
      context,
      BorrowingDetailSheet(borrowing: borrowing),
    );
    if (action == 'edit' && context.mounted) {
      await EditHistorySheet.open(
        context,
        DebtHistoryEntry(borrowing: borrowing),
      );
    } else if (action == 'delete' && context.mounted) {
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
    child: HistoryDetailContent(
      amountMinor: borrowing.amountMinor,
      date: borrowing.date,
      note: borrowing.note,
      isEdited: borrowing.isEdited,
      icon: Icons.add_rounded,
      iconColor: const Color(0xFF2673C7),
      iconBackground: const Color(0xFFD9EEF5),
      deleteLabel: 'ลบรายการกู้เพิ่ม',
      onEdit: () => Navigator.pop(context, 'edit'),
      onDelete: () => Navigator.pop(context, 'delete'),
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
