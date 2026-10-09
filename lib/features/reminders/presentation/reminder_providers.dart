import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/router/app_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../debt/presentation/providers/debt_providers.dart';
import '../data/notification_service.dart';
import '../data/reminder_repository.dart';
import '../domain/reminder_schedule.dart';
import '../domain/reminder_settings.dart';

final reminderRepositoryProvider = Provider(
  (ref) => ReminderRepository(ref.watch(databaseProvider)),
);
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(
    onTap: (debtId) {
      if (!ref.mounted) return;
      ref.read(selectedDebtIdProvider.notifier).select(debtId);
      ref.read(appRouterProvider).go('/');
    },
  ),
);
final reminderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final reminderControllerProvider =
    NotifierProvider<ReminderController, ReminderState>(ReminderController.new);

class ReminderState {
  const ReminderState({
    this.onboardingDone,
    this.settings,
    this.settingsByDebt = const {},
    this.permissionAllowed,
    this.zone,
    this.busy = false,
    this.loadError = false,
    this.syncError = false,
  });
  final bool? onboardingDone, permissionAllowed;
  final ReminderSettings? settings;
  final Map<String, ReminderSettings> settingsByDebt;
  ReminderSettings? forDebt(String id) =>
      settingsByDebt[id] ?? (settings?.debtId == id ? settings : null);
  final tz.Location? zone;
  final bool busy, loadError, syncError;
}

class ReminderController extends Notifier<ReminderState> {
  Future<void> _tail = Future.value();
  @override
  ReminderState build() => const ReminderState();

  // Serialize all writes and reconciliations. Each job reads fresh committed
  // data, so a delayed refresh can never reinstall an older schedule.
  Future<T> _enqueue<T>(Future<T> Function() job) {
    final next = _tail.then((_) => job());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> refresh() => _enqueue(_sync);

  /// Restore shares the reminder queue so an older reconciliation cannot
  /// reinstall the previous database's schedule after replacement.
  Future<void> restoreData(Future<void> Function() replace) =>
      _enqueue(() async {
        final saved = await ref.read(paymentActionProvider.notifier).run(
          () async {
            await replace();
            ref.read(selectedDebtIdProvider.notifier).select(null);
          },
        );
        if (!saved) {
          throw const AppException('กำลังบันทึกข้อมูล กรุณาลองกู้คืนอีกครั้ง');
        }
        await _sync();
      });

  Future<void> _sync() async {
    if (!ref.mounted) return;
    final previous = state;
    state = ReminderState(
      onboardingDone: previous.onboardingDone,
      settings: previous.settings,
      settingsByDebt: previous.settingsByDebt,
      permissionAllowed: previous.permissionAllowed,
      zone: previous.zone,
      busy: true,
      syncError: previous.syncError,
    );
    bool done;
    ReminderSettings? settings;
    final settingsByDebt = <String, ReminderSettings>{};
    final repository = ref.read(reminderRepositoryProvider);
    final service = ref.read(notificationServiceProvider);
    try {
      done = await repository.onboardingDone();
      if (!ref.mounted) return;
      final summaries = await ref.read(debtRepositoryProvider).loadAll();
      if (!ref.mounted) return;
      for (final summary in summaries) {
        final value = await repository.load(summary.debt.id);
        if (!ref.mounted) return;
        if (value != null) settingsByDebt[summary.debt.id] = value;
      }
      settings = summaries.isEmpty
          ? null
          : settingsByDebt[summaries.first.debt.id];
      if (!ref.mounted) return;
      state = ReminderState(
        onboardingDone: done,
        settings: settings,
        settingsByDebt: Map.unmodifiable(settingsByDebt),
        zone: previous.zone,
        busy: true,
      );
      try {
        await service.initialize();
        final zone = await service.localTimezone();
        final allowed = await service.permissionAllowed();
        final now = tz.TZDateTime.from(ref.read(reminderClockProvider)(), zone);
        final schedule = allowed
            ? ReminderSchedule.combine([
                for (final summary in summaries)
                  if (settingsByDebt[summary.debt.id] case final value?)
                    ...ReminderSchedule.build(
                      summary: summary,
                      settings: value,
                      now: now,
                    ),
              ])
            : <ScheduledReminder>[];
        if (!ref.mounted) return;
        state = ReminderState(
          onboardingDone: done,
          settings: settings,
          settingsByDebt: Map.unmodifiable(settingsByDebt),
          permissionAllowed: allowed,
          zone: zone,
          busy: true,
        );
        // Permission can be revoked externally; remove pending requests too.
        await service.replaceSchedule(schedule);
        if (!ref.mounted) return;
        state = ReminderState(
          onboardingDone: done,
          settings: settings,
          settingsByDebt: Map.unmodifiable(settingsByDebt),
          permissionAllowed: allowed,
          zone: zone,
        );
      } catch (_) {
        // Timezone/permission queries can fail before schedule replacement.
        // Clear stale dates and amounts whenever native cancellation is usable.
        try {
          await service.replaceSchedule([]);
        } catch (_) {
          // The retry notice also covers cancellation failures.
        }
        if (!ref.mounted) return;
        final current = state;
        state = ReminderState(
          onboardingDone: done,
          settings: settings,
          settingsByDebt: Map.unmodifiable(settingsByDebt),
          permissionAllowed: current.permissionAllowed,
          zone: current.zone,
          syncError: true,
        );
      }
    } catch (_) {
      if (!ref.mounted) return;
      // Without trustworthy database state, do not keep an old debt schedule.
      try {
        await service.replaceSchedule([]);
      } catch (_) {
        /* Retry on resume. */
      }
      if (!ref.mounted) return;
      state = ReminderState(
        onboardingDone: previous.onboardingDone,
        settings: previous.settings,
        settingsByDebt: previous.settingsByDebt,
        permissionAllowed: previous.permissionAllowed,
        zone: previous.zone,
        loadError: true,
        syncError: true,
      );
    }
  }

  Future<void> _write(Future<void> Function() action) async {
    final saved = await ref
        .read(paymentActionProvider.notifier)
        .run(action, refreshDebt: false);
    if (!saved) throw const AppException('กำลังบันทึกข้อมูล กรุณาลองอีกครั้ง');
  }

  Future<void> save(ReminderSettings settings) => _enqueue(() async {
    // Database errors propagate. Native scheduling errors are reported in state
    // by _sync, without presenting a committed write as failed.
    await _write(() => ref.read(reminderRepositoryProvider).save(settings));
    await _sync();
  });

  Future<bool> requestPermission() => _enqueue(() async {
    final allowed = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    await _sync();
    return allowed;
  });

  Future<void> completeOnboarding({required bool enable}) => _enqueue(() async {
    final repository = ref.read(reminderRepositoryProvider);
    if (enable) {
      await ref.read(notificationServiceProvider).requestPermission();
      final summary = await ref.read(debtRepositoryProvider).load();
      final settings = summary == null
          ? null
          : await repository.load(summary.debt.id);
      if (settings != null) await repository.save(settings.withEnabled(true));
    }
    await repository.completeOnboarding();
    await _sync();
  });

  Future<void> disable() => _enqueue(() async {
    final repository = ref.read(reminderRepositoryProvider);
    await _write(repository.disableAll);
    if (!ref.mounted) return;
    // The transaction has committed. Publish its result before scheduling so
    // even a subsequent read/native failure cannot restore old enabled flags.
    final previous = state;
    state = ReminderState(
      onboardingDone: previous.onboardingDone,
      settings: previous.settings?.withEnabled(false),
      settingsByDebt: Map.unmodifiable({
        for (final entry in previous.settingsByDebt.entries)
          entry.key: entry.value.withEnabled(false),
      }),
      permissionAllowed: previous.permissionAllowed,
      zone: previous.zone,
      busy: true,
      loadError: previous.loadError,
      syncError: previous.syncError,
    );
    await _sync();
  });

  Future<void> openSystemSettings() =>
      _enqueue(() => ref.read(notificationServiceProvider).openSettings());
}
