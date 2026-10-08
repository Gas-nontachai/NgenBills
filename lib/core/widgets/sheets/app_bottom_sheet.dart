import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

Future<T?> showAppSheet<T>(
  BuildContext context,
  Widget child, {
  bool guarded = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: !guarded,
  enableDrag: !guarded,
  barrierColor: AppColors.text.withValues(alpha: .55),
  builder: (_) => child,
);

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.onClose,
    this.onDragClose,
  });
  final Widget child;
  final String? title;
  final VoidCallback? onClose, onDragClose;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) > 80) onDragClose?.call();
              },
              child: SizedBox(
                height: 24,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: Text(title!, style: AppTypography.h2)),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'ปิด',
                      icon: const Icon(Icons.close, size: 22),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}
