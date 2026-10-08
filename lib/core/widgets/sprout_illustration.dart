import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Code-native illustration that stays crisp at any device scale.
class SproutIllustration extends StatelessWidget {
  const SproutIllustration({super.key, this.size = 200, this.wallet = false});
  final double size;
  final bool wallet;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SproutPainter(wallet)),
    ),
  );
}

class _SproutPainter extends CustomPainter {
  _SproutPainter(this.wallet);
  final bool wallet;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 200);
    final paint = Paint()..color = AppColors.primarySoft;
    canvas.drawOval(const Rect.fromLTWH(8, 15, 176, 166), paint);
    paint.color = AppColors.primary.withValues(alpha: .13);
    canvas.drawOval(const Rect.fromLTWH(45, 161, 120, 16), paint);
    final stem = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(102, 130)
        ..quadraticBezierTo(97, 94, 111, 53),
      stem,
    );
    paint.color = AppColors.primary;
    canvas.drawPath(
      Path()
        ..moveTo(106, 82)
        ..cubicTo(99, 57, 126, 55, 132, 30)
        ..cubicTo(140, 61, 124, 82, 106, 82),
      paint,
    );
    paint.color = AppColors.primaryDark.withValues(alpha: .6);
    canvas.drawPath(
      Path()
        ..moveTo(103, 103)
        ..cubicTo(73, 104, 84, 78, 61, 72)
        ..cubicTo(92, 70, 105, 83, 103, 103),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(108, 79)
        ..lineTo(126, 48),
      stem..strokeWidth = 1.4,
    );
    if (wallet) {
      canvas.save();
      canvas.translate(100, 137);
      canvas.rotate(-.16);
      paint.color = AppColors.primaryDark;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-47, -31, 96, 66),
          const Radius.circular(15),
        ),
        paint,
      );
      paint.shader = const LinearGradient(
        colors: [Color(0xFF9EB69B), AppColors.primary],
      ).createShader(const Rect.fromLTWH(-48, -22, 100, 65));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-49, -22, 98, 64),
          const Radius.circular(15),
        ),
        paint,
      );
      paint.shader = null;
      paint.color = AppColors.primarySoft;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, -3, 33, 26),
          const Radius.circular(8),
        ),
        paint,
      );
      paint.color = AppColors.primary;
      canvas.drawCircle(const Offset(33, 10), 4, paint);
      canvas.restore();
      paint.color = AppColors.gold;
      for (final point in [
        const Offset(33, 99),
        const Offset(165, 62),
        const Offset(172, 135),
      ]) {
        canvas.drawPath(
          Path()
            ..moveTo(point.dx, point.dy - 6)
            ..lineTo(point.dx + 3, point.dy - 1)
            ..lineTo(point.dx + 6, point.dy)
            ..lineTo(point.dx + 2, point.dy + 2)
            ..lineTo(point.dx, point.dy + 7)
            ..lineTo(point.dx - 2, point.dy + 2)
            ..lineTo(point.dx - 6, point.dy)
            ..lineTo(point.dx - 2, point.dy - 2)
            ..close(),
          paint,
        );
      }
    } else {
      paint.color = AppColors.primary;
      canvas.drawPath(
        Path()
          ..moveTo(76, 123)
          ..lineTo(128, 123)
          ..lineTo(121, 163)
          ..quadraticBezierTo(102, 174, 84, 163)
          ..close(),
        paint,
      );
      paint.color = AppColors.primaryDark;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(73, 121, 58, 10),
          const Radius.circular(4),
        ),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SproutPainter oldDelegate) =>
      oldDelegate.wallet != wallet;
}
