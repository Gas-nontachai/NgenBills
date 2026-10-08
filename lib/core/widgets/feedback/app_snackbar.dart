import 'package:flutter/material.dart';

import '../../errors/app_exception.dart';
import '../../../app/theme/app_colors.dart';

abstract final class AppSnackBar {
  static void show(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? AppColors.error : AppColors.primaryDark,
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Kanit',
              color: AppColors.surface,
            ),
          ),
        ),
      );
  }

  static void failure(BuildContext context, Object error) => show(
    context,
    error is AppException ? error.message : 'บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง',
    error: true,
  );
}
