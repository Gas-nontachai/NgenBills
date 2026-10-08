import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_schedule.dart';

abstract class NotificationService {
  Future<void> initialize();
  Future<tz.Location> localTimezone();
  Future<bool> permissionAllowed();
  Future<bool> requestPermission();
  Future<void> replaceSchedule(List<ScheduledReminder> reminders);
  Future<void> openSettings();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({required this.onTap});
  final VoidCallback onTap;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    if (_supported) {
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onTap(),
      );
      if (initialized != true) {
        throw StateError('Notification initialization failed');
      }
      _initialized = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) onTap();
    } else {
      _initialized = true;
    }
  }

  @override
  Future<tz.Location> localTimezone() async {
    await initialize();
    if (!_supported) return tz.UTC;
    final info = await FlutterTimezone.getLocalTimezone();
    final zone = tz.getLocation(info.identifier);
    tz.setLocalLocation(zone);
    return zone;
  }

  @override
  Future<bool> permissionAllowed() async {
    await initialize();
    if (!_supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()!
              .areNotificationsEnabled() ??
          false;
    }
    final options = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!
        .checkPermissions();
    return (options?.isEnabled ?? false) ||
        (options?.isProvisionalEnabled ?? false);
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (!_supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!
          .requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!
          .requestPermissions(alert: true, sound: true);
    }
    return permissionAllowed();
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    await initialize();
    if (!_supported) return;
    // This app only owns debt reminders. Cancel first so edits and disabling
    // cannot leave older amounts or dates pending.
    await _plugin.cancelAll();
    try {
      for (final reminder in reminders) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: reminder.at,
          payload: reminder.debtId,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'debt_due_reminders',
              'เตือนวันชำระหนี้',
              channelDescription: 'เตือนล่วงหน้าและในวันครบกำหนดชำระหนี้',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: 'ic_notification',
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } catch (_) {
      // Do not leave a partially replaced schedule presented as successful.
      await _plugin.cancelAll();
      rethrow;
    }
  }

  @override
  Future<void> openSettings() async {
    await initialize();
    if (!_supported) return;
    if (await _plugin.openAppNotificationSettings() != true) {
      throw StateError('Could not open notification settings');
    }
  }
}
