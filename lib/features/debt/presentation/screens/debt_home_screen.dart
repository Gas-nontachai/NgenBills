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
import 'empty_home_screen.dart';

class DebtHomeScreen extends ConsumerWidget {
  const DebtHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderControllerProvider);
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
            if (reminders.onboardingDone == null) {
              return Scaffold(
                body: reminders.loadError
                    ? AppErrorState(
                        onRetry: () => ref
                            .read(reminderControllerProvider.notifier)
                            .refresh(),
                      )
                    : const AppLoadingState(),
              );
            }
            if (!reminders.onboardingDone!) {
              return const NotificationOnboardingScreen();
            }
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
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        DebtProgressCard(summary: summary),
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
                                'ประวัติการจ่าย',
                                style: AppTypography.title,
                              ),
                            ),
                            Text(
                              '${summary.payments.length} รายการ',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (summary.payments.isEmpty)
                          const AppCard(
                            color: AppColors.primarySoft,
                            child: AppEmptyState(
                              title: 'ยังไม่มีประวัติการจ่าย',
                              message: 'มาบันทึกการจ่ายครั้งแรก\nเพื่อดูความคืบหน้าของคุณ',
                            ),
                          ),
                        ...summary.payments.map(
                          (payment) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PaymentListItem(payment: payment),
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
