import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
    required this.permissionListenable,
    this._accountScope,
  });

  static const String enabledKey = 'reflection_reminder_enabled';
  static const String timeKey = 'reflection_reminder_time';
  static const String notificationId = 'reflection_reminder';

  final SharedPrefsStore _preferences;
  final NotificationSchedulerPort _scheduler;
  final ValueListenable<bool?> permissionListenable;
  final String? _accountScope;

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
      await _scheduler.cancel(notificationId, accountScope: _accountScope);
      return false;
    }

    final bool granted = await _scheduler.requestPermissions();
    if (!granted) {
      await _preferences.save(enabledKey, 'false');
      await _scheduler.cancel(notificationId, accountScope: _accountScope);
      return false;
    }

    await _scheduler.scheduleDailyAt(
      id: notificationId,
      title: 'Daily Reflection',
      body: 'Take 3 minutes to review your day and set intent for tomorrow.',
      hour: time.hour,
      minute: time.minute,
      accountScope: _accountScope,
    );
    return true;
  }

  Future<void> setTime({required TimeOfDay time}) async {
    await _preferences.save(timeKey, '${time.hour}:${time.minute}');
    await _scheduler.scheduleDailyAt(
      id: notificationId,
      title: 'Daily Reflection',
      body: 'Take 3 minutes to review your day and set intent for tomorrow.',
      hour: time.hour,
      minute: time.minute,
      accountScope: _accountScope,
    );
  }

  Future<bool> requestNotificationPermission() {
    return _scheduler.requestPermissions();
  }
}

class VoicePermissionService {
  const VoicePermissionService();

  Future<bool> requestPermission() async {
    try {
      final PermissionStatus status = await Permission.microphone.request();
      return status.isGranted;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      debugPrint('VoicePermissionService unavailable: $error');
      return false;
    } catch (_) {
      return false;
    }
  }
}
