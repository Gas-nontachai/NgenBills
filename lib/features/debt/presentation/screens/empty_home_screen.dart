import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/app_logo.dart';

class EmptyHomeScreen extends StatelessWidget {
  const EmptyHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: AppLogo(size: 235),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'มาเริ่มจัดการ\nหนี้ก้อนแรกกัน',
                        style: AppTypography.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'แค่รู้ว่าเรามีหนี้เท่าไหร่\nก็เป็นจุดเริ่มต้นที่ดีแล้ว',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      AppButton(
                        label: 'เพิ่มหนี้ก้อนแรก',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () => context.push('/create'),
                      ),
                      const SizedBox(height: 48),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: AppColors.secondary,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'ข้อมูลของคุณ อยู่กับคุณเท่านั้น',
                              style: AppTypography.caption,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
