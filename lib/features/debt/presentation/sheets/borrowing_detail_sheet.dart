import '../../domain/services/debt_wording.dart';
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
  const BorrowingDetailSheet({
    super.key,
    required this.borrowing,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  DebtWording get wording => DebtWording(direction);
  final Borrowing borrowing;
  static Future<void> open(
    BuildContext context,
    Borrowing borrowing, {
    DebtDirection direction = DebtDirection.payable,
  }) async {
    final action = await showAppSheet<String>(
      context,
      BorrowingDetailSheet(borrowing: borrowing, direction: direction),
    );
    if (action == 'edit' && context.mounted) {
      await EditHistorySheet.open(
        context,
        DebtHistoryEntry(borrowing: borrowing),
        direction: direction,
      );
    } else if (action == 'delete' && context.mounted) {
      await showAppSheet<void>(
        context,
        DeleteBorrowingSheet(borrowing: borrowing, direction: direction),
        guarded: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: wording.borrowingDetail,
    onClose: () => Navigator.pop(context),
    child: HistoryDetailContent(
      amountMinor: borrowing.amountMinor,
      date: borrowing.date,
      note: borrowing.note,
      isEdited: borrowing.isEdited,
      icon: Icons.add_rounded,
      iconColor: const Color(0xFF2673C7),
      iconBackground: const Color(0xFFD9EEF5),
      deleteLabel: wording.deleteBorrowing,
      onEdit: () => Navigator.pop(context, 'edit'),
      onDelete: () => Navigator.pop(context, 'delete'),
    ),
  );
}

class DeleteBorrowingSheet extends ConsumerStatefulWidget {
  const DeleteBorrowingSheet({
    super.key,
    required this.borrowing,
    this.direction = DebtDirection.payable,
  });
  final DebtDirection direction;
  final Borrowing borrowing;
  @override
  ConsumerState<DeleteBorrowingSheet> createState() =>
      _DeleteBorrowingSheetState();
}

class _DeleteBorrowingSheetState extends ConsumerState<DeleteBorrowingSheet> {
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
              .read(borrowingRepositoryProvider)
              .delete(widget.borrowing.id);
        },
      );
      if (mounted && saved) {
        AppSnackBar.show(
          context,
          existed ? wording.deleteBorrowingSaved : 'รายการนี้ถูกลบไปแล้ว',
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
      title: wording.deleteBorrowing,
      message: wording.borrowingDeleteExplanation,
      confirmLabel: wording.deleteBorrowing,
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
