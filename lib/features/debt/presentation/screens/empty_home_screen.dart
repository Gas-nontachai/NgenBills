import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../reminders/presentation/reminder_widgets.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../sheets/create_debt_sheet.dart';
import '../../domain/entities/debt_direction.dart';
import '../widgets/debt_direction_chip.dart';

class EmptyHomeScreen extends StatelessWidget {
  const EmptyHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          tooltip: 'ตั้งค่าและกู้คืนข้อมูล',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
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
                      const SizedBox(height: 20),
                      const Text(
                        'เริ่มได้ทั้งเงินที่ต้องจ่ายคืน และเงินที่รอรับคืน',
                        style: AppTypography.small,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DebtDirectionChip(
                                direction: DebtDirection.payable,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'ฉันต้องจ่ายเงินคืน',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DebtDirectionChip(
                                direction: DebtDirection.receivable,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'ฉันรอรับเงินคืน',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const ReminderSyncNotice(),
                      AppButton(
                        label: 'เพิ่มหนี้ก้อนแรก',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: () =>
                            CreateDebtSheet.open(context, additional: false),
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
