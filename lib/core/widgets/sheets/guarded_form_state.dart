import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bottom_sheet.dart';
import 'app_confirm_sheet.dart';

/// Forms own dismissal so native drag/back cannot discard data or interrupt a write.
abstract class GuardedFormState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  bool saving = false, confirming = false, _allowClose = false;
  bool get dirty;

  Future<void> close() async {
    if (saving || confirming) return;
    if (dirty) {
      confirming = true;
      final discard = await showAppSheet<bool>(
        context,
        Builder(
          builder: (dialogContext) => AppConfirmSheet(
            title: 'ละทิ้งข้อมูลที่กรอกไว้?',
            message: 'ข้อมูลนี้ยังไม่ได้บันทึก คุณกลับไปแก้ไขต่อได้',
            confirmLabel: 'ละทิ้งข้อมูล',
            onConfirm: () => Navigator.pop(dialogContext, true),
            onCancel: () => Navigator.pop(dialogContext, false),
          ),
        ),
      );
      confirming = false;
      if (!mounted || discard != true) return;
    }
    await finish();
  }

  Future<void> finish([Object? result]) async {
    if (!mounted) return;
    setState(() => _allowClose = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  Widget guardedSheet({required String title, required Widget child}) =>
      PopScope(
        canPop: _allowClose,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) close();
        },
        child: AppBottomSheet(
          title: title,
          onClose: saving ? null : close,
          onDragClose: close,
          child: child,
        ),
      );
}
