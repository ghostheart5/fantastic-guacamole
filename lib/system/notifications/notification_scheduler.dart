import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

enum NotificationScheduleResult {
  scheduled,
  skippedNotInitialized,
  skippedPermissionDenied,
  skippedPastTime,
}

class NotificationScheduler {
  factory NotificationScheduler() => _instance;

  NotificationScheduler._() : _plugin = FlutterLocalNotificationsPlugin();

  static final NotificationScheduler _instance = NotificationScheduler._();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _permissionGranted = true;
  static String? _pendingNotificationPayload;
  static final ValueNotifier<bool?> permissionGrantedListenable =
      ValueNotifier<bool?>(null);
  static final ValueNotifier<String?> notificationPayloadListenable =
      ValueNotifier<String?>(null);

  static String? consumePendingNotificationPayload() {
    final String? payload = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    return payload;
  }

  static const _channel = AndroidNotificationChannel(
    'chronospark_channel',
    'ChronoSpark',
    description: 'ChronoSpark reminders and alerts',
    importance: Importance.high,
  );

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'chronospark_channel',
      'ChronoSpark',
      channelDescription: 'ChronoSpark reminders and alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  Future<bool> init({bool requestPermissions = false}) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload?.trim();
        if (payload == null || payload.isEmpty) {
          return;
        }
        _pendingNotificationPayload = payload;
        notificationPayloadListenable.value = payload;
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );
    _initialized = true;

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final MacOSFlutterLocalNotificationsPlugin? macosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);

    if (!requestPermissions) {
      _permissionGranted =
          await androidPlugin?.areNotificationsEnabled() ?? false;
      permissionGrantedListenable.value = _permissionGranted;
      return _permissionGranted;
    }

    bool granted = true;
    final bool? androidGranted = await androidPlugin
        ?.requestNotificationsPermission();
    if (androidGranted != null) {
      granted = granted && androidGranted;
    }

    final bool? iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) {
      granted = granted && iosGranted;
    }

    final bool? macosGranted = await macosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (macosGranted != null) {
      granted = granted && macosGranted;
    }

    _permissionGranted = granted;
    permissionGrantedListenable.value = _permissionGranted;
    if (_permissionGranted) {
      Logger.log('Notifications', 'Notification permission granted.');
      RuntimeDiagnostics.record('Notification permission granted.');
    } else {
      Logger.warn('Notification permission denied; schedules will be skipped.');
      RuntimeDiagnostics.record(
        'Notification permission denied; schedules will be skipped.',
      );
    }
    return _permissionGranted;
  }

  Future<bool> requestPermissions() => init(requestPermissions: true);

  Future<void> schedule(NotificationEntity notification) async {
    await scheduleWithStatus(notification);
  }

  Future<NotificationScheduleResult> scheduleWithStatus(
    NotificationEntity notification,
  ) async {
    if (!_initialized) {
      Logger.warn(
        'Skipped schedule because notification scheduler is not initialized.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule because scheduler is not initialized.',
      );
      return NotificationScheduleResult.skippedNotInitialized;
    }
    if (!_permissionGranted) {
      Logger.log(
        'Notifications',
        'Skipped schedule because permission is not granted.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule because permission is not granted.',
      );
      return NotificationScheduleResult.skippedPermissionDenied;
    }
    final scheduledTz = tz.TZDateTime.from(notification.scheduledAt, tz.local);
    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) {
      Logger.log(
        'Notifications',
        'Skipped schedule for past time: ${notification.id}.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule for past time: ${notification.id}.',
      );
      return NotificationScheduleResult.skippedPastTime;
    }
    await _plugin.zonedSchedule(
      id: _notificationId(notification.id),
      title: notification.title,
      body: notification.message,
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      payload: jsonEncode(<String, String>{
        'route': '/notifications',
        'notificationId': notification.id,
      }),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return NotificationScheduleResult.scheduled;
  }

  Future<void> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await scheduleDailyAtWithStatus(
      id: id,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
    );
  }

  Future<NotificationScheduleResult> scheduleDailyAtWithStatus({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) {
      return NotificationScheduleResult.skippedNotInitialized;
    }
    if (!_permissionGranted) {
      return NotificationScheduleResult.skippedPermissionDenied;
    }
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _notificationId(id),
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _notifDetails,
      payload: jsonEncode(<String, String>{
        'route': '/notifications',
        'notificationId': id,
      }),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return NotificationScheduleResult.scheduled;
  }

  Future<void> cancel(String id) async {
    if (!_initialized) {
      Logger.log(
        'Notifications',
        'Skipped cancel because scheduler is not initialized.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification cancel because scheduler is not initialized.',
      );
      return;
    }
    await _plugin.cancel(id: _notificationId(id));
  }

  Future<void> cancelAll() async {
    if (!_initialized) {
      Logger.log(
        'Notifications',
        'Skipped cancel-all because scheduler is not initialized.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification cancel-all because scheduler is not initialized.',
      );
      return;
    }
    await _plugin.cancelAll();
  }

  static int _notificationId(String value) {
    int hash = 0x811c9dc5;
    for (final int codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  final String? payload = response.payload?.trim();
  if (payload == null || payload.isEmpty) {
    return;
  }
  NotificationScheduler._pendingNotificationPayload = payload;
  NotificationScheduler.notificationPayloadListenable.value = payload;
}
