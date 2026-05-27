class NotificationSettings {
  static const keyEnabled = 'notif_enabled';
  static const keySleepStart = 'notif_sleep_start';
  static const keySleepEnd = 'notif_sleep_end';

  final bool enabled;
  final int sleepStartMinute; // minutes from midnight, default 23*60
  final int sleepEndMinute;   // minutes from midnight, default 7*60

  const NotificationSettings({
    this.enabled = true,
    this.sleepStartMinute = 1380,
    this.sleepEndMinute = 420,
  });

  NotificationSettings copyWith({
    bool? enabled,
    int? sleepStartMinute,
    int? sleepEndMinute,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        sleepStartMinute: sleepStartMinute ?? this.sleepStartMinute,
        sleepEndMinute: sleepEndMinute ?? this.sleepEndMinute,
      );
}
