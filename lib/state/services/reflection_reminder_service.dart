import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum NotificationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  unknown,
}

@immutable
class ReflectionReminderPrefs {
  const ReflectionReminderPrefs({required this.enabled, required this.time});

  final bool enabled;
  final TimeOfDay time;
}

class ReflectionReminderService {
  ReflectionReminderService({
    required this._preferences,
    required this._scheduler,
  });

  static const String enabledKey = 'reflection_reminder_enabled';
  static const String timeKey = 'reflection_reminder_time';
  static const String notificationId = 'reflection_reminder';

  final SharedPrefsStore _preferences;
  final NotificationScheduler _scheduler;

  ValueListenable<bool?> get permissionListenable {
    return NotificationScheduler.permissionGrantedListenable;
  }

  ReflectionReminderPrefs loadPrefs() {
    final String? enabledStr = _preferences.load(enabledKey);
    final String? timeStr = _preferences.load(timeKey);

    bool enabled = enabledStr == 'true';
    TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);

    if (timeStr != null) {
      final List<String> parts = timeStr.split(':');
      if (parts.length == 2) {
        time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 20,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    return ReflectionReminderPrefs(enabled: enabled, time: time);
  }

  Future<bool> setEnabled({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    await _preferences.save(enabledKey, enabled.toString());

    if (!enabled) {
      await _scheduler.cancel(notificationId);
      return false;
    }

    final bool granted = await _scheduler.requestPermissions();
    if (!granted) {
      await _preferences.save(enabledKey, 'false');
      await _scheduler.cancel(notificationId);
      return false;
    }

    final NotificationScheduleResult result = await _scheduler
        .scheduleDailyAtWithStatus(
      id: notificationId,
      title: 'Daily Reflection',
      body: 'Take 3 minutes to review your day and set intent for tomorrow.',
      hour: time.hour,
      minute: time.minute,
    );
    if (result != NotificationScheduleResult.scheduled) {
      await _preferences.save(enabledKey, 'false');
      await _scheduler.cancel(notificationId);
      return false;
    }
    return true;
  }

  Future<void> setTime({required TimeOfDay time}) async {
    await _preferences.save(timeKey, '${time.hour}:${time.minute}');
    await _scheduler.scheduleDailyAtWithStatus(
      id: notificationId,
      title: 'Daily Reflection',
      body: 'Take 3 minutes to review your day and set intent for tomorrow.',
      hour: time.hour,
      minute: time.minute,
    );
  }

  Future<bool> requestNotificationPermission() {
    return _scheduler.requestPermissions();
  }

  Future<NotificationPermissionState> requestNotificationPermissionDetailed() async {
    await _scheduler.requestPermissions();
    return getNotificationPermissionState();
  }

  Future<NotificationPermissionState> getNotificationPermissionState() async {
    if (kIsWeb) {
      final bool? granted = permissionListenable.value;
      if (granted == true) {
        return NotificationPermissionState.granted;
      }
      if (granted == false) {
        return NotificationPermissionState.denied;
      }
      return NotificationPermissionState.unknown;
    }

    final PermissionStatus status = await Permission.notification.status;
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => NotificationPermissionState.granted,
      PermissionStatus.permanentlyDenied ||
      PermissionStatus.restricted => NotificationPermissionState.permanentlyDenied,
      PermissionStatus.denied => NotificationPermissionState.denied,
    };
  }
}

class VoicePermissionService {
  const VoicePermissionService();

  Future<bool> requestPermission() async {
    return false;
  }
}
