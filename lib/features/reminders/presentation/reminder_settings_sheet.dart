import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/sheets/app_bottom_sheet.dart';
import '../domain/reminder_settings.dart';
import 'reminder_providers.dart';

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
  int? _day;
  int _daysBefore = 3;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _enabled = false, _onDueDate = true, _busy = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(reminderControllerProvider).settings;
    if (settings != null && settings.debtId == widget.debtId) {
      _day = settings.dueDay;
      _daysBefore = settings.daysBefore;
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
      await ref
          .read(reminderControllerProvider.notifier)
          .save(
            ReminderSettings(
              debtId: widget.debtId,
              dueDay: _day!,
              daysBefore: _daysBefore,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(widget.debtName),
              subtitle: const Text('ตั้งค่าเตือนวันชำระหนี้ทุกเดือน'),
            ),
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
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _day,
              decoration: const InputDecoration(
                labelText: 'วันครบกำหนดชำระ (ทุกเดือน)',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              hint: const Text('เลือกวันที่'),
              items: List.generate(
                31,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(
                    'วันที่ ${i + 1} ของทุกเดือน',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              onChanged: _busy ? null : (day) => setState(() => _day = day),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'เดือนที่ไม่มีวันที่เลือก จะใช้วันสุดท้ายของเดือน',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _daysBefore,
              decoration: const InputDecoration(
                labelText: 'แจ้งเตือนล่วงหน้า',
                prefixIcon: Icon(Icons.notifications_outlined),
              ),
              items: const [0, 1, 3, 7]
                  .map(
                    (days) => DropdownMenuItem(
                      value: days,
                      child: Text(
                        days == 0
                            ? 'ไม่แจ้งเตือนล่วงหน้า'
                            : '$days วันก่อนครบกำหนด',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (days) => setState(() => _daysBefore = days!),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _time,
                        initialEntryMode: TimePickerEntryMode.input,
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
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('แจ้งเตือนซ้ำในวันครบกำหนด'),
              value: _onDueDate,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _onDueDate = value!),
            ),
            if (_daysBefore == 0 && !_onDueDate)
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
