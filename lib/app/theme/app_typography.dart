import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w500);
  static const title = TextStyle(fontSize: 18, fontWeight: FontWeight.w500);
  static const body = TextStyle(fontSize: 16, height: 1.5);
  static const small = TextStyle(
    fontSize: 14,
    color: AppColors.secondary,
    height: 1.5,
  );
  static const caption = TextStyle(fontSize: 12, color: AppColors.secondary);
}
