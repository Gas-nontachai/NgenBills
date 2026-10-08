import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class HalfDonutChart extends StatelessWidget {
  const HalfDonutChart({
    super.key,
    required this.progress,
    required this.center,
  });
  final double progress;
  final Widget center;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ชำระแล้ว ${(progress.clamp(0, 1) * 100).round()} เปอร์เซ็นต์',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(100.0, 380.0);
        return SizedBox(
          width: width,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: AppSpacing.animation,
            builder: (context, value, child) => ConstrainedBox(
              constraints: BoxConstraints(minHeight: width / 2 + 14),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: Size(width, width / 2 + 14),
                      painter: _ArcPainter(value),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: width * .23, bottom: 12),
                    child: Center(child: center),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, radius + stroke / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border;
    canvas.drawArc(rect, math.pi, math.pi, false, paint);
    if (progress > 0) {
      paint.shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
      ).createShader(rect);
      canvas.drawArc(rect, math.pi, math.pi * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
