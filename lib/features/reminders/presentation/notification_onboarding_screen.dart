import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import 'reminder_providers.dart';

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
    // Keep app-level handles before the gate swaps this screen.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final container = ProviderScope.containerOf(context);
    try {
      await ref
          .read(reminderControllerProvider.notifier)
          .completeOnboarding(enable: enable);
      if (navigator.mounted) {
        await showDialog<void>(
          context: navigator.context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              scrollable: true,
              title: const Text(
                'ยินดีด้วย! 🎉',
                style: AppTypography.h2,
                textAlign: TextAlign.center,
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    size: 64,
                    color: AppColors.primaryDark,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'คุณเริ่มต้นจัดการหนี้ก้อนแรกแล้ว\n'
                    'ก้าวแรกสำเร็จแล้ว มาค่อย ๆ ไปด้วยกันนะ 🌱',
                    style: AppTypography.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                AppButton(
                  label: 'ตกลง',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        );
      }
      if (enable && messenger.mounted) {
        final status = container.read(reminderControllerProvider);
        if (status.permissionAllowed != true) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('ยังไม่ได้รับอนุญาต เปิดสิทธิ์ได้ใน Settings'),
            ),
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
