import 'package:flutter/material.dart';

import '../buttons/app_button.dart';
import 'app_empty_state.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppEmptyState(
            title: 'โหลดข้อมูลไม่สำเร็จ',
            message: 'ลองอีกครั้งเพื่อกลับมาติดตามความคืบหน้าของคุณ',
            icon: Icons.cloud_off_rounded,
          ),
          AppButton(label: 'ลองอีกครั้ง', onPressed: onRetry),
        ],
      ),
    ),
  );
}
