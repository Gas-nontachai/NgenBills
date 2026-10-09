import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../domain/reminder_settings.dart';
import 'reminder_providers.dart';
import 'due_day_sheet.dart';
import '../../../app/theme/app_colors.dart';
import '../../debt/presentation/widgets/account_context_header.dart';

class ReminderSettingsSheet extends ConsumerStatefulWidget {
  const ReminderSettingsSheet({
    super.key,
    required this.debtId,
    required this.debtName,
  });
  final String debtId, debtName;

  static Future<void> open(
    BuildContext context,
    String debtId,
    String debtName,
  ) => showAppSheet<void>(
    context,
    ReminderSettingsSheet(debtId: debtId, debtName: debtName),
  );

  @override
  ConsumerState<ReminderSettingsSheet> createState() =>
      _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends ConsumerState<ReminderSettingsSheet> {
  int? _day = 1;
  Set<int> _advanceDays = {3};
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _enabled = true, _onDueDate = true, _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref
        .read(reminderControllerProvider)
        .forDebt(widget.debtId);
    if (settings != null && settings.debtId == widget.debtId) {
      _day = settings.dueDay;
      _advanceDays = Set.of(settings.advanceDays);
      _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
      _enabled = settings.enabled;
      _onDueDate = settings.remindOnDueDate;
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() {
      _enabled = value;
      _busy = value;
    });
    if (!value) return;
    try {
      final allowed = await ref
          .read(reminderControllerProvider.notifier)
          .requestPermission();
      if (mounted && !allowed) {
        AppSnackBar.show(
          context,
          'ยังไม่ได้รับอนุญาต กรุณาเปิดสิทธิ์ในการตั้งค่าของเครื่อง',
        );
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context,
          'ตรวจสิทธิ์ไม่สำเร็จ กรุณาลองอีกครั้ง',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_day == null || _busy) return;
    setState(() => _busy = true);
    try {
      final controller = ref.read(reminderControllerProvider.notifier);
      if (_enabled &&
          ref.read(reminderControllerProvider).permissionAllowed != true) {
        await controller.requestPermission();
        if (!mounted) return;
      }
      await controller.save(
        ReminderSettings(
          debtId: widget.debtId,
          dueDay: _day!,
          advanceDays: Set.unmodifiable(_advanceDays),
          hour: _time.hour,
          minute: _time.minute,
          enabled: _enabled,
          remindOnDueDate: _onDueDate,
        ),
      );
      if (!mounted) return;
      final status = ref.read(reminderControllerProvider);
      final message = status.loadError || status.syncError
          ? 'บันทึกการตั้งค่าแล้ว แต่จัดตารางเตือนไม่สำเร็จ ลองใหม่ได้ใน Settings'
          : !_enabled
          ? 'บันทึกวันครบกำหนดแล้ว · ปิดการแจ้งเตือนอยู่'
          : status.permissionAllowed != true
          ? 'บันทึกการตั้งค่าแล้ว · กรุณาเปิดสิทธิ์แจ้งเตือนในการตั้งค่าของเครื่อง'
          : _advanceDays.isEmpty && !_onDueDate
          ? 'บันทึกวันครบกำหนดแล้ว · ไม่ได้เลือกวันแจ้งเตือน'
          : 'บันทึกการตั้งค่าแล้ว · เตือนเวลา ${_time.format(context)}';
      AppSnackBar.show(context, message);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) AppSnackBar.failure(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(reminderControllerProvider);
    return PopScope(
      canPop: !_busy,
      child: AppBottomSheet(
        title: 'ตั้งค่าการแจ้งเตือน',
        onClose: _busy ? null : () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountContextHeader(debtId: widget.debtId, name: widget.debtName),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('เปิดการแจ้งเตือน'),
              subtitle: const Text('แจ้งเตือนผ่านโทรศัพท์ของคุณ'),
              value: _enabled,
              onChanged: _busy ? null : _toggle,
            ),
            if (_enabled && status.permissionAllowed == false)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await ref
                              .read(reminderControllerProvider.notifier)
                              .openSystemSettings();
                        } catch (_) {
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              'เปิดการตั้งค่าไม่ได้',
                              error: true,
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('เปิดสิทธิ์ในตั้งค่าของเครื่อง'),
              ),
            const Divider(height: 24, color: AppColors.border),
            const Text(
              'วันครบกำหนดชำระ:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(14),
              ),
              onPressed: _busy
                  ? null
                  : () async {
                      final day = await DueDaySheet.open(context, _day);
                      if (day != null && mounted) setState(() => _day = day);
                    },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Row(
                children: [
                  Expanded(
                    child: Text(_day == null ? 'เลือกวันที่' : 'วันที่ $_day'),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('แจ้งเตือนเมื่อไหร่ (เลือกได้มากกว่า 1)'),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final single =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(16) > 24;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [7, 3, 1, 0].map((days) {
                    final selected = days == 0
                        ? _onDueDate
                        : _advanceDays.contains(days);
                    return SizedBox(
                      width: single
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 8) / 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          backgroundColor: selected
                              ? AppColors.primarySoft
                              : AppColors.surface,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primaryDark
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                if (days == 0) {
                                  _onDueDate = !_onDueDate;
                                } else if (selected) {
                                  _advanceDays.remove(days);
                                } else {
                                  _advanceDays.add(days);
                                }
                              }),
                        child: Semantics(
                          checked: selected,
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: selected
                                    ? AppColors.primaryDark
                                    : AppColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  days == 0 ? 'วันครบกำหนด' : '$days วันก่อน',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('เวลาแจ้งเตือน'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: _busy
                  ? null
                  : () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _time,
                        initialEntryMode: TimePickerEntryMode.dial,
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(alwaysUse24HourFormat: true),
                          child: child!,
                        ),
                      );
                      if (time != null && mounted) setState(() => _time = time);
                    },
              icon: const Icon(Icons.schedule),
              label: Text(
                'เวลาแจ้งเตือน ${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')} น.',
              ),
            ),
            if (_advanceDays.isEmpty && !_onDueDate)
              const Text('ไม่ได้เลือกวันเตือน จะบันทึกเฉพาะวันครบกำหนด'),
            const Text(
              'เวลาที่เลือกเป็นเวลาเป้าหมาย การประหยัดแบตเตอรี่อาจทำให้แจ้งเตือนช้าลง',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'บันทึกการตั้งค่า',
              onPressed: _day == null || _busy ? null : _save,
              isLoading: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
