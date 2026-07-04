import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationScheduler {
  NotificationScheduler() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _permissionGranted = true;
  static final ValueNotifier<bool?> permissionGrantedListenable =
      ValueNotifier<bool?>(null);

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

  Future<void> init() async {
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
    await _plugin.initialize(settings: settings);

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
  }

  Future<void> schedule(NotificationEntity notification) async {
    if (!_permissionGranted) {
      Logger.log(
        'Notifications',
        'Skipped schedule because permission is not granted.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule because permission is not granted.',
      );
      return;
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
      return;
    }
    await _plugin.zonedSchedule(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.message,
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_permissionGranted) return;
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
      id: id.hashCode,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(String id) async {
    await _plugin.cancel(id: id.hashCode);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
