class ReminderSettings {
  const ReminderSettings({
    required this.debtId,
    required this.dueDay,
    this.daysBefore = 3,
    this.hour = 9,
    this.minute = 0,
    this.enabled = false,
    this.remindOnDueDate = true,
  });

  final String debtId;
  final int dueDay, daysBefore, hour, minute;
  final bool enabled, remindOnDueDate;

  void validate() {
    if (dueDay < 1 ||
        dueDay > 31 ||
        !const [0, 1, 3, 7].contains(daysBefore) ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw ArgumentError('Invalid reminder settings');
    }
  }

  ReminderSettings withEnabled(bool value) => ReminderSettings(
    debtId: debtId,
    dueDay: dueDay,
    daysBefore: daysBefore,
    hour: hour,
    minute: minute,
    enabled: value,
    remindOnDueDate: remindOnDueDate,
  );

  Map<String, Object?> toMap() => {
    'debt_id': debtId,
    'due_day': dueDay,
    'days_before': daysBefore,
    'hour': hour,
    'minute': minute,
    'enabled': enabled ? 1 : 0,
    'remind_on_due_date': remindOnDueDate ? 1 : 0,
  };

  factory ReminderSettings.fromMap(Map<String, Object?> row) =>
      ReminderSettings(
        debtId: row['debt_id'] as String,
        dueDay: row['due_day'] as int,
        daysBefore: row['days_before'] as int,
        hour: row['hour'] as int,
        minute: row['minute'] as int,
        enabled: row['enabled'] == 1,
        remindOnDueDate: row['remind_on_due_date'] == 1,
      );
}
