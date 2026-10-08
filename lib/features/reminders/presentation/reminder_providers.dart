import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/router/app_router.dart';
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
    onTap: () {
      if (ref.mounted) ref.read(appRouterProvider).go('/');
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
    this.permissionAllowed,
    this.zone,
    this.busy = false,
    this.loadError = false,
    this.syncError = false,
  });
  final bool? onboardingDone, permissionAllowed;
  final ReminderSettings? settings;
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

  Future<void> _sync() async {
    if (!ref.mounted) return;
    final previous = state;
    state = ReminderState(
      onboardingDone: previous.onboardingDone,
      settings: previous.settings,
      permissionAllowed: previous.permissionAllowed,
      zone: previous.zone,
      busy: true,
      syncError: previous.syncError,
    );
    bool done;
    ReminderSettings? settings;
    final repository = ref.read(reminderRepositoryProvider);
    final service = ref.read(notificationServiceProvider);
    try {
      done = await repository.onboardingDone();
      final summary = await ref.read(debtRepositoryProvider).load();
      settings = summary == null
          ? null
          : await repository.load(summary.debt.id);
      if (!ref.mounted) return;
      state = ReminderState(
        onboardingDone: done,
        settings: settings,
        zone: previous.zone,
        busy: true,
      );
      try {
        await service.initialize();
        final zone = await service.localTimezone();
        final allowed = await service.permissionAllowed();
        final now = tz.TZDateTime.from(ref.read(reminderClockProvider)(), zone);
        final schedule = summary == null || settings == null || !allowed
            ? <ScheduledReminder>[]
            : ReminderSchedule.build(
                summary: summary,
                settings: settings,
                now: now,
              );
        if (!ref.mounted) return;
        state = ReminderState(
          onboardingDone: done,
          settings: settings,
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
        permissionAllowed: previous.permissionAllowed,
        zone: previous.zone,
        loadError: true,
        syncError: true,
      );
    }
  }

  Future<void> save(ReminderSettings settings) => _enqueue(() async {
    // Database errors propagate. Native scheduling errors are reported in state
    // by _sync, without presenting a committed write as failed.
    await ref.read(reminderRepositoryProvider).save(settings);
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
    final summary = await ref.read(debtRepositoryProvider).load();
    final settings = summary == null
        ? null
        : await repository.load(summary.debt.id);
    if (settings != null) await repository.save(settings.withEnabled(false));
    await _sync();
  });

  Future<void> openSystemSettings() =>
      _enqueue(() => ref.read(notificationServiceProvider).openSettings());
}
