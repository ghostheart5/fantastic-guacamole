import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum NotificationPermissionState { granted, denied, permanentlyDenied, unknown }

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
    required this.storageScope,
    required this.registry,
    this.scheduleDailyAt,
  });

  static const String enabledKey = 'reflection_reminder_enabled';
  static const String timeKey = 'reflection_reminder_time';
  static const String notificationId = 'reflection_reminder';

  final SharedPrefsStore _preferences;
  final NotificationScheduler _scheduler;
  final AccountStorageScope storageScope;
  final ReminderOrchestratorService registry;
  final Future<NotificationScheduleResult> Function(
      String id,
      String title,
      String body,
      int hour,
      int minute,
    )? scheduleDailyAt;

  String get _namespace => storageScope.v2Namespace ??
      (throw StateError('Reflection reminders require an authenticated scope.'));
  String get _enabledKey => 'reflection_reminder_enabled_v2.$_namespace';
  String get _timeKey => 'reflection_reminder_time_v2.$_namespace';
  String get _notificationId => 'reminder.reflection.$_namespace.default';

  ValueListenable<bool?> get permissionListenable {
    return NotificationScheduler.permissionGrantedListenable;
  }

  ReflectionReminderPrefs loadPrefs() {
    if (!storageScope.isAuthenticated) return const ReflectionReminderPrefs(enabled: false, time: TimeOfDay(hour: 20, minute: 0));
    final String? enabledStr = _preferences.load(_enabledKey);
    final String? timeStr = _preferences.load(_timeKey);

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
    await _preferences.save(_enabledKey, enabled.toString());

    if (!enabled) {
      await registry.cancelRegisteredReminder(scope: storageScope, id: _notificationId);
      return false;
    }

    final bool granted = await _scheduler.requestPermissions();
    if (!granted) {
      await _preferences.save(_enabledKey, 'false');
      return false;
    }

    final NotificationScheduleResult result = await _schedule(
      time: time,
    );
    if (result != NotificationScheduleResult.scheduled) {
      await _preferences.save(_enabledKey, 'false');
      return false;
    }
    await registry.registerScheduledReminder(scope: storageScope, id: _notificationId);
    return true;
  }

  Future<void> setTime({required TimeOfDay time}) async {
    await _preferences.save(_timeKey, '${time.hour}:${time.minute}');
    final NotificationScheduleResult result = await _schedule(time: time);
    if (result != NotificationScheduleResult.scheduled) {
      return;
    }
    await registry.registerScheduledReminder(scope: storageScope, id: _notificationId);
  }

  Future<NotificationScheduleResult> _schedule({required TimeOfDay time}) {
    const String title = 'Daily Reflection';
    const String body = 'Take 3 minutes to review your day and set intent for tomorrow.';
    final scheduleDailyAt = this.scheduleDailyAt;
    if (scheduleDailyAt != null) {
      return scheduleDailyAt(_notificationId, title, body, time.hour, time.minute);
    }
    return _scheduler.scheduleDailyAtWithStatus(
      id: _notificationId,
      title: title,
      body: body,
      hour: time.hour,
      minute: time.minute,
    );
  }

  Future<bool> requestNotificationPermission() {
    return _scheduler.requestPermissions();
  }

  Future<NotificationPermissionState>
  requestNotificationPermissionDetailed() async {
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
      PermissionStatus.permanentlyDenied || PermissionStatus.restricted =>
        NotificationPermissionState.permanentlyDenied,
      PermissionStatus.denied => NotificationPermissionState.denied,
    };
  }
}

class VoicePermissionService {
  const VoicePermissionService();

  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return true;
    }

    final PermissionStatus status = await Permission.microphone.request();
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited ||
        status == PermissionStatus.provisional;
  }
}
