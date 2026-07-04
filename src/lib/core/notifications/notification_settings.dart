class NotificationSettings {
  static const keyEnabled = 'notif_enabled';
  static const keySleepStart = 'notif_sleep_start';
  static const keySleepEnd = 'notif_sleep_end';

  // Single source for fallback defaults, shared by every prefs read site.
  static const defaultEnabled = true;
  static const defaultSleepStart = 1380; // 23:00
  static const defaultSleepEnd = 420; // 07:00

  final bool enabled;
  final int sleepStartMinute; // minutes from midnight, default 23*60
  final int sleepEndMinute;   // minutes from midnight, default 7*60

  const NotificationSettings({
    this.enabled = defaultEnabled,
    this.sleepStartMinute = defaultSleepStart,
    this.sleepEndMinute = defaultSleepEnd,
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
