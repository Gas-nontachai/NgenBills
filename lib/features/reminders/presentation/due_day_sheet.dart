import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/sheets/app_bottom_sheet.dart';

class DueDaySheet extends StatefulWidget {
  const DueDaySheet({super.key, this.initialDay});
  final int? initialDay;

  static Future<int?> open(BuildContext context, int? day) =>
      showAppSheet<int>(context, DueDaySheet(initialDay: day));

  @override
  State<DueDaySheet> createState() => _DueDaySheetState();
}

class _DueDaySheetState extends State<DueDaySheet> {
  late int? _day = widget.initialDay;

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: 'วันครบกำหนดชำระ',
    onClose: () => Navigator.pop(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final height = 44.0 * scale;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 31,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                mainAxisExtent: height,
              ),
              itemBuilder: (context, index) {
                final day = index + 1;
                final selected = day == _day;
                return Semantics(
                  selected: selected,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: selected
                          ? AppColors.primaryDark
                          : AppColors.background,
                      foregroundColor: selected ? Colors.white : AppColors.text,
                      side: BorderSide(
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.border,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => setState(() => _day = day),
                    child: Text('$day'),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'เดือนที่ไม่มีวันที่เลือก\nจะใช้วันสุดท้ายของเดือน',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'ยืนยัน',
          onPressed: _day == null ? null : () => Navigator.pop(context, _day),
        ),
      ],
    ),
  );
}
