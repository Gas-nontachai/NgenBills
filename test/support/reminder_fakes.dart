import 'package:ngenbills/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ngenbills/features/reminders/data/notification_service.dart';
import 'package:ngenbills/features/reminders/data/reminder_repository.dart';
import 'package:ngenbills/features/reminders/domain/reminder_schedule.dart';
import 'package:ngenbills/features/reminders/domain/reminder_settings.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MemoryReminderRepository extends ReminderRepository {
  MemoryReminderRepository({this.done = true})
    : super(AppDatabase(factory: databaseFactoryFfi));
  bool done;
  bool failWrites = false;
  final settings = <String, ReminderSettings>{};
  @override
  Future<ReminderSettings?> load(String debtId) async => settings[debtId];
  @override
  Future<void> save(ReminderSettings value) async {
    if (failWrites) throw StateError('write failed');
    value.validate();
    settings[value.debtId] = value;
  }

  @override
  Future<void> disableAll() async {
    if (failWrites) throw StateError('write failed');
    for (final id in settings.keys.toList()) {
      settings[id] = settings[id]!.withEnabled(false);
    }
  }

  @override
  Future<bool> onboardingDone() async => done;
  @override
  Future<void> completeOnboarding() async {
    done = true;
  }
}

class FakeNotificationService implements NotificationService {
  FakeNotificationService() {
    tzdata.initializeTimeZones();
  }
  bool allowed = true;
  bool grantOnRequest = true;
  bool failSchedule = false;
  bool failInitialize = false;
  bool failPermission = false;
  int requests = 0, settingsOpened = 0;
  String zoneName = 'Asia/Bangkok';
  List<ScheduledReminder> pending = [];
  final history = <List<ScheduledReminder>>[];
  @override
  Future<void> initialize() async {
    if (failInitialize) throw StateError('initialize failed');
  }

  @override
  Future<tz.Location> localTimezone() async => tz.getLocation(zoneName);
  @override
  Future<bool> permissionAllowed() async => allowed;
  @override
  Future<bool> requestPermission() async {
    requests++;
    if (failPermission) throw StateError('permission failed');
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    pending = [];
    if (failSchedule) throw StateError('schedule failed');
    pending = List.of(reminders);
    history.add(List.of(reminders));
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}
