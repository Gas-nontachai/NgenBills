import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../../../../core/widgets/sheets/app_delete_sheet.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../domain/services/debt_summary.dart';
import '../widgets/account_avatar.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../domain/entities/debt.dart';
import '../providers/debt_providers.dart';
import '../../../reminders/presentation/reminder_providers.dart';

class DeleteDebtSheet extends ConsumerStatefulWidget {
  const DeleteDebtSheet({super.key, required this.debt});
  final Debt debt;
  static Future<bool?> open(BuildContext context, Debt debt) =>
      showAppSheet<bool>(context, DeleteDebtSheet(debt: debt), guarded: true);
  @override
  ConsumerState<DeleteDebtSheet> createState() => _DeleteDebtSheetState();
}

class _DeleteDebtSheetState extends ConsumerState<DeleteDebtSheet> {
  bool _saving = false;
  late final DebtSummary? _summary = _loadSummary();
  DebtSummary? _loadSummary() {
    final summary = ref.read(debtSummaryProvider).asData?.value;
    return summary?.debt.id == widget.debt.id ? summary : null;
  }

  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(paymentActionProvider.notifier)
          .run(
            () => ref
                .read(debtRepositoryProvider)
                .delete(widget.debt.id)
                .then((_) {}),
          );
      if (!saved) return;
      // Reconcile explicitly before leaving: deleting the final debt clears native reminders.
      // Reconciliation is independent of the committed deletion.
      ref.read(reminderControllerProvider.notifier).refresh();
      if (mounted) {
        AppSnackBar.show(context, 'ลบบัญชีแล้ว');
        setState(() => _saving = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _defaultImpact() {
    final accounts = ref.watch(accountsProvider).value ?? [];
    if (accounts.length == 1) return '\nหลังลบจะกลับหน้าว่าง';
    if (ref.watch(defaultDebtIdProvider).value == widget.debt.id) {
      final remaining = accounts.where((a) => a.id != widget.debt.id);
      if (remaining.isNotEmpty) {
        return '\n“${remaining.first.name}” จะเป็นบัญชีหลักแทน';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppDeleteSheet(
      title: 'ลบบัญชี “${widget.debt.name}”?',
      message:
          'การลบบัญชีจะลบประวัติทั้งหมด และยกเลิกการแจ้งเตือนของบัญชีนี้ด้วย${_defaultImpact()}',
      warningTitle: 'บัญชีและข้อมูลทั้งหมดจะถูกลบถาวร',
      warningMessage: 'ไม่สามารถกู้คืนข้อมูลได้',
      warningItems: const [
        'ยอดหนี้และยอดคงเหลือ',
        'ประวัติการจ่ายทั้งหมด',
        'ประวัติการกู้เพิ่มทั้งหมด',
        'การตั้งค่าและการแจ้งเตือน',
      ],
      accountDeletion: true,
      confirmLabel: 'ลบอย่างถาวร',
      isLoading: _saving,
      onConfirm: ref.watch(paymentActionProvider) ? null : _delete,
      onCancel: () => Navigator.pop(context, false),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccountAvatar(
                iconKey: widget.debt.iconKey,
                colorKey: widget.debt.colorKey,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.debt.name, style: AppTypography.title),
                    const Text('บัญชีที่จะลบ', style: AppTypography.small),
                  ],
                ),
              ),
            ],
          ),
          if (_summary != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  DeleteDetailRow(
                    label: 'ยอดหนี้คงเหลือ',
                    value: Money.format(_summary.remaining),
                    emphasis: true,
                  ),
                  const SizedBox(height: 12),
                  DeleteDetailRow(
                    label: 'ยอดหนี้รวม',
                    value: Money.format(_summary.totalDebt),
                    emphasis: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
