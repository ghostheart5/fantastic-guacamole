import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';

class NotificationPolicy {
  static bool canSchedule(NotificationEntity notification, {DateTime? now}) {
    if (!notification.isEnabled) return false;
    final DateTime reference = now ?? DateTime.now();
    return notification.scheduledAt.isAfter(reference);
  }

  static bool canDispatch(
    NotificationEntity notification, {
    required DateTime now,
    required List<NotificationEntity> recentlySent,
    bool permissionEnabled = true,
    bool isHighPriority = false,
    Duration cooldown = const Duration(minutes: 10),
    Duration repeatWindow = const Duration(minutes: 30),
  }) {
    if (!permissionEnabled) return false;
    if (isHighPriority) return true;
    if (!respectsCooldown(now, recentlySent, cooldown: cooldown)) return false;
    if (isSpammyRepeat(
      notification,
      recentlySent,
      repeatWindow: repeatWindow,
    )) {
      return false;
    }
    return true;
  }

  static bool respectsCooldown(
    DateTime now,
    List<NotificationEntity> recentlySent, {
    Duration cooldown = const Duration(minutes: 10),
  }) {
    if (recentlySent.isEmpty) return true;
    final DateTime latest = recentlySent
        .map((NotificationEntity n) => n.scheduledAt)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
    return !now.isBefore(latest.add(cooldown));
  }

  static bool isSpammyRepeat(
    NotificationEntity candidate,
    List<NotificationEntity> recentlySent, {
    Duration repeatWindow = const Duration(minutes: 30),
  }) {
    final String candidateKey = _repeatKey(candidate);
    for (final NotificationEntity sent in recentlySent) {
      if (_repeatKey(sent) != candidateKey) continue;
      final Duration diff = candidate.scheduledAt.difference(sent.scheduledAt);
      if (diff.abs() < repeatWindow) {
        return true;
      }
    }
    return false;
  }

  static String _repeatKey(NotificationEntity notification) {
    return '${notification.title.trim().toLowerCase()}|${notification.message.trim().toLowerCase()}';
  }
}
