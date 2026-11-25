part of 'reminder_orchestrator_service.dart';

/// A daily stretch of time in which reminders the app picks the time for
/// itself are held back until it ends. Times the person chose (rhythms,
/// daily planning, reflection) are never moved.
@immutable
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startMinutes = defaultStartMinutes,
    this.endMinutes = defaultEndMinutes,
  });

  static const int defaultStartMinutes = 22 * 60;
  static const int defaultEndMinutes = 7 * 60;

  final bool enabled;

  /// Minutes after local midnight.
  final int startMinutes;
  final int endMinutes;

  /// Whether a local time of day falls inside. The end itself is outside.
  bool contains(int minuteOfDay) {
    if (!enabled || startMinutes == endMinutes) return false;
    return startMinutes < endMinutes
        ? minuteOfDay >= startMinutes && minuteOfDay < endMinutes
        : minuteOfDay >= startMinutes || minuteOfDay < endMinutes;
  }

  /// [at], or the next end of quiet hours when [at] falls inside them, in
  /// the device time zone (`tz.local`). Keeps [at]'s UTC or local form.
  DateTime moveOut(DateTime at) {
    if (!enabled || startMinutes == endMinutes) return at;
    final tz.TZDateTime local = tz.TZDateTime.from(at, tz.local);
    if (!contains(local.hour * 60 + local.minute)) return at;
    tz.TZDateTime end(int dayOffset) => tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day + dayOffset,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
    final tz.TZDateTime moved = end(0).isAfter(local) ? end(0) : end(1);
    final int ms = moved.millisecondsSinceEpoch;
    return at.isUtc
        ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

extension _ReminderControls on ReminderOrchestratorService {
  QuietHours _quietHours() => QuietHours(
    enabled: _isEnabled(
      ReminderOrchestratorService._quietHoursEnabledKey,
      defaultValue: false,
    ),
    startMinutes: _storedMinutes(
      ReminderOrchestratorService._quietHoursStartKey,
      QuietHours.defaultStartMinutes,
    ),
    endMinutes: _storedMinutes(
      ReminderOrchestratorService._quietHoursEndKey,
      QuietHours.defaultEndMinutes,
    ),
  );

  /// A stored "hour:minute" time as minutes after midnight, or [fallback].
  int _storedMinutes(String key, int fallback) {
    final List<String> parts = (_preferences.load(key) ?? '').split(':');
    if (parts.length != 2) return fallback;
    final int? hour = int.tryParse(parts[0].trim());
    final int? minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return fallback;
    return hour.clamp(0, 23).toInt() * 60 + minute.clamp(0, 59).toInt();
  }
}
