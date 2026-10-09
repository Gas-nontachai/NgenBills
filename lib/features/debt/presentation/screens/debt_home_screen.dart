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
import '../../domain/entities/debt.dart';
import '../../domain/services/debt_summary.dart';
import '../widgets/account_avatar.dart';
import '../widgets/debt_progress_card.dart';
import '../widgets/borrowing_list_item.dart';
import 'empty_home_screen.dart';
import '../widgets/account_swipe_card.dart';
import '../sheets/account_picker_sheet.dart';
import '../sheets/create_debt_sheet.dart';

class DebtHomeScreen extends ConsumerStatefulWidget {
  const DebtHomeScreen({super.key});
  @override
  ConsumerState<DebtHomeScreen> createState() => _DebtHomeScreenState();
}

class _DebtHomeScreenState extends ConsumerState<DebtHomeScreen> {
  final _scroll = ScrollController();
  String? _lastActiveId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!ref.read(paymentActionProvider)) {
      await CreateDebtSheet.open(context);
    }
  }

  Future<void> _select(String id) async {
    if (ref.read(paymentActionProvider)) return;
    final accounts = ref.read(accountsProvider).value ?? [];
    if (!accounts.any((account) => account.id == id)) {
      ref.invalidate(accountsProvider);
      ref.invalidate(defaultDebtIdProvider);
      return;
    }
    // Selection is immediate. Each account's provider owns its load, so an
    // older request cannot commit an outdated selection after another swipe.
    final target = debtSummaryByIdProvider(id);
    if (ref.read(target).hasError) ref.invalidate(target);
    ref.read(selectedDebtIdProvider.notifier).select(id);
  }

  Future<void> _openPicker(String currentId) async {
    if (ref.read(paymentActionProvider)) return;
    final result = await AccountPickerSheet.open(
      context,
      ref.read(accountsProvider).value ?? [],
      currentId,
      ref.read(defaultDebtIdProvider).value,
    );
    if (!mounted || result == null) return;
    if (result.create) {
      _create();
    } else if (result.debtId != null) {
      await _select(result.debtId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);
    final defaultState = ref.watch(defaultDebtIdProvider);
    final selected = ref.watch(selectedDebtIdProvider);
    final reminders = ref.watch(reminderControllerProvider);
    final writing = ref.watch(paymentActionProvider);
    return accountsState.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: AppLoadingState()),
      error: (error, stack) => Scaffold(
        body: AppErrorState(
          onRetry: () {
            ref.invalidate(accountsProvider);
            ref.invalidate(defaultDebtIdProvider);
          },
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const EmptyHomeScreen();
        }
        if (reminders.onboardingDone == null && !reminders.loadError) {
          return const Scaffold(body: AppLoadingState());
        }
        if (reminders.onboardingDone == false) {
          return const NotificationOnboardingScreen();
        }
        final defaultId = defaultState.value;
        final activeId = accounts.any((a) => a.id == selected)
            ? selected!
            : (accounts.any((a) => a.id == defaultId)
                  ? defaultId!
                  : accounts.first.id);
        if (_lastActiveId != activeId) {
          _lastActiveId = activeId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
          });
        }
        // The carousel and history read the same ID, including cached pages.
        final details = ref.watch(debtSummaryByIdProvider(activeId));
        final summary =
            !details.isLoading &&
                !details.hasError &&
                details.value?.debt.id == activeId
            ? details.value
            : null;
        return Scaffold(
          appBar: AppBar(
            title: const AppBrandTitle(),
            actions: [
              IconButton(
                tooltip: 'ตั้งค่า',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  children: [
                    if (writing)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('กำลังบันทึก…'),
                          ],
                        ),
                      ),
                    AccountSwipeCard(
                      accountIds: accounts.map((a) => a.id).toList(),
                      selectedId: activeId,
                      enabled: !writing,
                      onSelect: _select,
                      onCreate: _create,
                      itemBuilder: (context, index, active) => _AccountPage(
                        debt: accounts[index],
                        accounts: accounts,
                        index: index,
                        defaultId: defaultId,
                        active: active,
                        enabled: !writing,
                        onSelect: _select,
                        onPicker: _openPicker,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: summary != null
                          ? _AccountDetails(
                              key: ValueKey(activeId),
                              summary: summary,
                            )
                          : details.hasError ||
                                (!details.isLoading && details.value == null)
                          ? AppErrorState(
                              onRetry: () {
                                ref.invalidate(
                                  debtSummaryByIdProvider(activeId),
                                );
                                ref.invalidate(accountsProvider);
                                ref.invalidate(defaultDebtIdProvider);
                              },
                            )
                          : const SizedBox(
                              height: 160,
                              child: AppLoadingState(),
                            ),
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

class _AccountPage extends ConsumerWidget {
  const _AccountPage({
    required this.debt,
    required this.accounts,
    required this.index,
    required this.defaultId,
    required this.active,
    required this.enabled,
    required this.onSelect,
    required this.onPicker,
  });
  final Debt debt;
  final List<Debt> accounts;
  final int index;
  final String? defaultId;
  final bool active, enabled;
  final Future<void> Function(String) onSelect, onPicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writing = !enabled;
    return ref
        .watch(debtSummaryByIdProvider(debt.id))
        .when(
          skipLoadingOnRefresh: false,
          loading: () => _placeholder(),
          error: (error, stack) => _placeholder(error: true),
          data: (summary) => summary == null
              ? _placeholder(error: true)
              : DebtProgressCard(
                  summary: summary,
                  interactive: active,
                  accountHeader: InkWell(
                    onTap: writing ? null : () => onPicker(debt.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                debt.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.title,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more_rounded,
                              key: active
                                  ? const ValueKey('account-picker-arrow')
                                  : null,
                              semanticLabel: 'เลือกบัญชี',
                              size: 20,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                        if (defaultId == debt.id)
                          const Text('บัญชีหลัก', style: AppTypography.caption),
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
                          tooltip: active ? 'บัญชีก่อนหน้า' : null,
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(28, 32),
                            fixedSize: const Size(28, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: writing || index <= 0
                              ? null
                              : () => onSelect(accounts[index - 1].id),
                          icon: const Icon(Icons.chevron_left, size: 20),
                        ),
                        InkWell(
                          onTap: writing ? null : () => onPicker(debt.id),
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
                          tooltip: active ? 'บัญชีถัดไป' : null,
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(28, 32),
                            fixedSize: const Size(28, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed:
                              writing ||
                                  index < 0 ||
                                  index + 1 >= accounts.length
                              ? null
                              : () => onSelect(accounts[index + 1].id),
                          icon: const Icon(Icons.chevron_right, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
        );
  }

  Widget _placeholder({bool error = false}) => AppCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AccountAvatar(iconKey: debt.iconKey, colorKey: debt.colorKey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                debt.name,
                style: AppTypography.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 270,
          child: Center(
            child: error
                ? const Text('โหลดบัญชีไม่สำเร็จ', style: AppTypography.small)
                : const SizedBox(
                    width: 160,
                    height: 12,
                    child: ColoredBox(color: AppColors.border),
                  ),
          ),
        ),
      ],
    ),
  );
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({super.key, required this.summary});
  final DebtSummary summary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ReminderSyncNotice(),
      const SizedBox(height: 16),
      AppButton(
        label: summary.isPaid ? 'ชำระครบแล้ว' : 'บันทึกการจ่าย',
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
            child: Text('ประวัติรายการ', style: AppTypography.title),
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
              : BorrowingListItem(borrowing: entry.borrowing!),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'ค่อย ๆ จ่าย ค่อย ๆ ไป 🌱',
        style: AppTypography.caption,
        textAlign: TextAlign.center,
      ),
    ],
  );
}
