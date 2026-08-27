import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationScheduler {
  factory NotificationScheduler() => _instance;

  NotificationScheduler._() : _plugin = FlutterLocalNotificationsPlugin();

  static final NotificationScheduler _instance = NotificationScheduler._();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _permissionGranted = true;
  static final ValueNotifier<bool?> permissionGrantedListenable =
      ValueNotifier<bool?>(null);

  /// The payload of the most recently tapped notification.
  ///
  /// Set both for a tap while the app is running and for a cold launch from a
  /// notification (see [consumeLaunchPayload]). Previously no response handler
  /// was registered at all, so tapping a reminder did nothing beyond opening
  /// the app and a launch-from-notification was indistinguishable from a
  /// normal launch.
  static final ValueNotifier<String?> tappedPayloadListenable =
      ValueNotifier<String?>(null);

  /// Payload the app was launched with, if it was launched by a notification
  /// tap. Returns null once consumed so a later read cannot re-route.
  Future<String?> consumeLaunchPayload() async {
    if (!_initialized) {
      return null;
    }
    try {
      final NotificationAppLaunchDetails? details = await _plugin
          .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) {
        return null;
      }
      final String? payload = details.notificationResponse?.payload;
      if (payload == null || payload.isEmpty) {
        return null;
      }
      return payload;
    } on Object catch (error) {
      Logger.warn('Failed to read notification launch details: $error');
      return null;
    }
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    Logger.log(
      'Notifications',
      payload == null || payload.isEmpty
          ? 'Notification tapped without a route payload.'
          : 'Notification tapped; route payload withheld from diagnostics.',
    );
    RuntimeDiagnostics.record('Notification tapped.');
    if (payload != null && payload.isNotEmpty) {
      tappedPayloadListenable.value = payload;
    }
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
      visibility: NotificationVisibility.private,
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
      onDidReceiveNotificationResponse: _handleNotificationResponse,
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
      // Query the platform we are actually on. This previously read
      // `androidPlugin?.areNotificationsEnabled() ?? false`, so on iOS/macOS —
      // where androidPlugin is null — it always resolved to false and every
      // later schedule() call silently skipped. Goal, habit and daily-planning
      // reminders never scheduled on iOS as a result.
      if (androidPlugin != null) {
        _permissionGranted =
            await androidPlugin.areNotificationsEnabled() ?? false;
      } else if (iosPlugin != null) {
        _permissionGranted =
            (await iosPlugin.checkPermissions())?.isAlertEnabled ?? false;
      } else if (macosPlugin != null) {
        _permissionGranted =
            (await macosPlugin.checkPermissions())?.isAlertEnabled ?? false;
      } else {
        // No supported local-notification implementation on this platform
        // (desktop/web). Nothing to schedule against.
        _permissionGranted = false;
      }
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

  Future<void> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    if (!notification.isEnabled) {
      // In-app-only entries (task completion/skip feedback and similar
      // transient toasts) are persisted for the in-app notification list but
      // must never reach the OS. Without this guard every task interaction
      // posted a real system notification one second later.
      return;
    }
    if (!_initialized) {
      Logger.warn(
        'Skipped schedule because notification scheduler is not initialized.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule because scheduler is not initialized.',
      );
      return;
    }
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
      Logger.log('Notifications', 'Skipped schedule for past time.');
      RuntimeDiagnostics.record('Skipped notification schedule for past time.');
      return;
    }
    await _plugin.zonedSchedule(
      id: _notificationId(_platformKey(notification.id, accountScope)),
      title: notification.title,
      body: notification.message,
      scheduledDate: scheduledTz,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Carry the domain id so a tap can be routed back to what it refers to.
      payload: accountScope == null
          ? notification.id
          : accountPayload(accountScope, notification.id),
    );
  }

  Future<void> scheduleDailyAt({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? accountScope,
  }) async {
    if (!_initialized) {
      Logger.warn(
        'Skipped daily schedule "$id" because the scheduler is not '
        'initialized.',
      );
      RuntimeDiagnostics.record(
        'Skipped daily notification schedule: scheduler not initialized.',
      );
      return;
    }
    if (!_permissionGranted) {
      Logger.log(
        'Notifications',
        'Skipped daily schedule "$id" because permission is not granted.',
      );
      RuntimeDiagnostics.record(
        'Skipped daily notification schedule: permission not granted.',
      );
      return;
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
      id: _notificationId(_platformKey(id, accountScope)),
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: accountScope == null ? id : accountPayload(accountScope, id),
    );
  }

  Future<void> cancel(String id, {String? accountScope}) async {
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
    await _plugin.cancel(id: _notificationId(_platformKey(id, accountScope)));
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

  static String _platformKey(String id, String? accountScope) {
    return accountScope == null ? id : '$accountScope:$id';
  }

  static String accountPayload(String accountScope, String notificationId) {
    return jsonEncode(<String, Object>{
      'v': 1,
      'accountScope': accountScope,
      'notificationId': notificationId,
    });
  }

  static ({String accountScope, String notificationId})? parseAccountPayload(
    String payload,
  ) {
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      if (decoded['v'] != 1) return null;
      final String accountScope = decoded['accountScope']?.toString() ?? '';
      final String notificationId = decoded['notificationId']?.toString() ?? '';
      if (accountScope.isEmpty || notificationId.isEmpty) return null;
      return (accountScope: accountScope, notificationId: notificationId);
    } on FormatException {
      return null;
    }
  }
}
