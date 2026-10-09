import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../reminders/presentation/notification_onboarding_screen.dart';
import '../../../reminders/presentation/reminder_providers.dart';
import '../../../reminders/presentation/reminder_widgets.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/states/app_empty_state.dart';
import '../../../../core/widgets/states/app_error_state.dart';
import '../../../../core/widgets/states/app_loading_state.dart';
import '../../../payment/presentation/widgets/add_payment_sheet.dart';
import '../../../payment/presentation/widgets/payment_list_item.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_progress_card.dart';
import '../widgets/borrowing_list_item.dart';
import 'empty_home_screen.dart';
import '../widgets/account_swipe_card.dart';
import '../sheets/account_picker_sheet.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';

class DebtHomeScreen extends ConsumerWidget {
  const DebtHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderControllerProvider);
    final accounts = ref.watch(accountsProvider).value ?? [];
    final defaultId = ref.watch(defaultDebtIdProvider).value;
    final writing = ref.watch(paymentActionProvider);
    void create() {
      if (!ref.read(paymentActionProvider)) context.push('/create');
    }

    Future<void> select(String id) async {
      if (ref.read(paymentActionProvider)) return;
      try {
        final latest = await ref.read(debtRepositoryProvider).list();
        if (!context.mounted || ref.read(paymentActionProvider)) return;
        if (latest.any((a) => a.id == id)) {
          ref.read(selectedDebtIdProvider.notifier).select(id);
        } else {
          ref.read(selectedDebtIdProvider.notifier).select(null);
          ref.invalidate(accountsProvider);
          ref.invalidate(defaultDebtIdProvider);
        }
      } catch (error) {
        if (context.mounted) AppSnackBar.failure(context, error);
      }
    }

    Future<void> openPicker(String currentId) async {
      if (ref.read(paymentActionProvider)) return;
      final result = await AccountPickerSheet.open(
        context,
        accounts,
        currentId,
        defaultId,
      );
      if (!context.mounted || result == null) return;
      if (result.create) {
        create();
      } else if (result.debtId != null) {
        await select(result.debtId!);
      }
    }

    return ref
        .watch(debtSummaryProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const Scaffold(body: AppLoadingState()),
          error: (error, stack) => Scaffold(
            body: AppErrorState(
              onRetry: () => ref.invalidate(debtSummaryProvider),
            ),
          ),
          data: (summary) {
            if (summary == null) return const EmptyHomeScreen();
            // Offer notification onboarding only once a debt actually exists.
            if (reminders.onboardingDone == null && !reminders.loadError) {
              return Scaffold(body: const AppLoadingState());
            }
            if (reminders.onboardingDone == false) {
              return const NotificationOnboardingScreen();
            }
            final index = accounts.indexWhere((a) => a.id == summary.debt.id);
            return Scaffold(
              appBar: AppBar(
                title: const AppBrandTitle(),
                actions: [
                  IconButton(
                    tooltip: 'การแจ้งเตือน',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings/notifications'),
                  ),
                ],
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: ListView(
                      key: ValueKey(summary.debt.id),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        if (writing)
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('กำลังบันทึก…'),
                            ],
                          ),
                        AccountSwipeCard(
                          key: ValueKey('swipe-${summary.debt.id}'),
                          enabled: !writing,
                          last: index == accounts.length - 1,
                          onCreate: create,
                          onPrevious: () {
                            if (index > 0) {
                              select(accounts[index - 1].id);
                            }
                          },
                          onNext: () {
                            if (index >= 0 && index + 1 < accounts.length) {
                              select(accounts[index + 1].id);
                            }
                          },
                          child: DebtProgressCard(
                            summary: summary,
                            accountHeader: InkWell(
                              onTap: writing
                                  ? null
                                  : () => openPicker(summary.debt.id),
                              borderRadius: BorderRadius.circular(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    summary.debt.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.title,
                                  ),
                                  if (defaultId == summary.debt.id)
                                    const Text(
                                      'บัญชีหลัก',
                                      style: AppTypography.caption,
                                    ),
                                ],
                              ),
                            ),
                            accountNavigation: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'บัญชีก่อนหน้า',
                                    style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 32),
                                      fixedSize: const Size(28, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: writing || index <= 0
                                        ? null
                                        : () => select(accounts[index - 1].id),
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      size: 20,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: writing
                                        ? null
                                        : () => openPicker(summary.debt.id),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        '${index + 1} / ${accounts.length}',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'บัญชีถัดไป',
                                    style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(28, 32),
                                      fixedSize: const Size(28, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed:
                                        writing ||
                                            index < 0 ||
                                            index + 1 >= accounts.length
                                        ? null
                                        : () => select(accounts[index + 1].id),
                                    icon: const Icon(
                                      Icons.chevron_right,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const ReminderSyncNotice(),
                        const SizedBox(height: 16),
                        AppButton(
                          label: summary.isPaid
                              ? 'ชำระครบแล้ว'
                              : 'บันทึกการจ่าย',
                          icon: summary.isPaid
                              ? Icons.check_circle_outline
                              : Icons.add_circle_outline,
                          onPressed: summary.isPaid
                              ? null
                              : () => AddPaymentSheet.open(context, summary),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'ประวัติรายการ',
                                style: AppTypography.title,
                              ),
                            ),
                            Text(
                              '${summary.history.length} รายการ',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (summary.history.isEmpty)
                          const AppCard(
                            color: AppColors.primarySoft,
                            child: AppEmptyState(
                              title: 'ยังไม่มีประวัติรายการ',
                              message: 'บันทึกการจ่ายหรือกู้เพิ่ม\nเพื่อเริ่มติดตามบัญชีของคุณ',
                            ),
                          ),
                        ...summary.history.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: entry.payment != null
                                ? PaymentListItem(payment: entry.payment!)
                                : BorrowingListItem(
                                    borrowing: entry.borrowing!,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'ค่อย ๆ จ่าย ค่อย ๆ ไป 🌱',
                          style: AppTypography.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
  }
}
