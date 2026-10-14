import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/debt_direction.dart';

String _label(DebtDirection direction) =>
    direction == DebtDirection.payable ? 'ลูกหนี้' : 'เจ้าหนี้';

Color _color(DebtDirection direction) => direction == DebtDirection.payable
    ? AppColors.dueUrgent
    : AppColors.primaryDark;

/// A small, read-only account label. Color supplements the written direction.
class DebtDirectionChip extends StatelessWidget {
  const DebtDirectionChip({super.key, required this.direction});
  final DebtDirection direction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _color(direction).withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          direction == DebtDirection.payable
              ? Icons.north_east_rounded
              : Icons.south_west_rounded,
          size: 13,
          color: _color(direction),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            _label(direction),
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: _color(direction),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A compact account-type field with a connected capsule toggle.
class DebtDirectionToggle extends StatelessWidget {
  const DebtDirectionToggle({super.key, required this.value, this.onChanged});
  final DebtDirection value;
  final ValueChanged<DebtDirection>? onChanged;

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ประเภทบัญชี'),
        scrollable: true,
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DebtDirectionChip(direction: DebtDirection.payable),
            SizedBox(height: 6),
            Text('คุณเป็นฝ่ายต้องจ่ายเงินคืน'),
            SizedBox(height: 16),
            DebtDirectionChip(direction: DebtDirection.receivable),
            SizedBox(height: 6),
            Text('คุณเป็นฝ่ายรอรับเงินคืน'),
            SizedBox(height: 20),
            Text(
              'เลือกก่อนสร้างบัญชี เพราะเปลี่ยนประเภทภายหลังไม่ได้',
              style: AppTypography.small,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final stacked = constraints.maxWidth < 320 || scale > 1.2;
      final label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'ประเภทบัญชี',
              style: AppTypography.small.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'เกี่ยวกับประเภทบัญชี',
            onPressed: onChanged == null ? null : () => _showInfo(context),
            icon: const Icon(Icons.info_outline_rounded, size: 18),
            color: AppColors.secondary,
          ),
        ],
      );
      final toggle = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            for (final direction in DebtDirection.values)
              Expanded(
                child: Semantics(
                  selected: value == direction,
                  button: true,
                  enabled: onChanged != null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: value == direction
                          ? _color(direction).withValues(alpha: .12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(direction),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 32),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 5,
                            ),
                            child: Center(
                              child: Text(
                                _label(direction),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: value == direction
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: onChanged == null
                                      ? AppColors.secondary
                                      : value == direction
                                      ? _color(direction)
                                      : AppColors.secondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [label, const SizedBox(height: 4), toggle],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: label),
          const SizedBox(width: 8),
          SizedBox(width: 144, child: toggle),
        ],
      );
    },
  );
}
