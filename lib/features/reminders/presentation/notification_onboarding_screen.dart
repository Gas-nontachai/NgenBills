import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../debt/presentation/providers/debt_providers.dart';
import 'reminder_providers.dart';
import 'reminder_settings_sheet.dart';

class NotificationOnboardingScreen extends ConsumerStatefulWidget {
  const NotificationOnboardingScreen({super.key});
  @override
  ConsumerState<NotificationOnboardingScreen> createState() =>
      _OnboardingState();
}

class _OnboardingState extends ConsumerState<NotificationOnboardingScreen> {
  bool _busy = false;
  Future<void> _finish(bool enable) async {
    setState(() => _busy = true);
    // Keep the navigator and messenger before the gate swaps this screen.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await ref
          .read(reminderControllerProvider.notifier)
          .completeOnboarding(enable: enable);
      if (enable && navigator.mounted) {
        final status = container.read(reminderControllerProvider);
        if (status.permissionAllowed != true) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('ยังไม่ได้รับอนุญาต เปิดสิทธิ์ได้ใน Settings'),
            ),
          );
        }
        final summary = container.read(debtSummaryProvider).value;
        if (summary != null && status.settings == null) {
          await ReminderSettingsSheet.open(
            navigator.context,
            summary.debt.id,
            summary.debt.name,
          );
        }
      }
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 94,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'ให้เงินบิล\nช่วยเตือนนะ',
                  textAlign: TextAlign.center,
                  style: AppTypography.h1,
                ),
                const SizedBox(height: 14),
                const Text(
                  'ไม่ต้องจำวันจ่ายหนี้ด้วยตัวเอง\nเราจะคอยเตือนคุณเมื่อใกล้ถึงวันครบกำหนด',
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
                const SizedBox(height: 26),
                const AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.calendar_today_outlined),
                        title: Text('ไม่พลาดวันจ่ายหนี้'),
                      ),
                      ListTile(
                        leading: Icon(Icons.schedule),
                        title: Text('เลือกวันและเวลาเองได้'),
                      ),
                      ListTile(
                        leading: Icon(Icons.shield_outlined),
                        title: Text('ข้อมูลของคุณอยู่บนเครื่องนี้'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'เปิดการแจ้งเตือน',
                  onPressed: _busy ? null : () => _finish(true),
                  isLoading: _busy,
                ),
                TextButton(
                  onPressed: _busy ? null : () => _finish(false),
                  child: const Text('ไว้ทีหลัง'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
