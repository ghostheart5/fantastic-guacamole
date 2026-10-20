import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/debug/runtime_diagnostics.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/ports/notification_scheduler_port.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationScheduler implements NotificationSchedulerPort {
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

  ValueListenable<bool?> get permissionStatusListenable =>
      permissionGrantedListenable;

  @override
  void clearTappedPayload() {
    tappedPayloadListenable.value = null;
  }

  /// Read actual registered reminders for this account, without rescheduling.
  Future<
    List<
      ({
        String id,
        String title,
        String body,
        int? hour,
        int? minute,
        HabitCadence? cadence,
        DateTime? firstScheduledLocal,
        bool cadenceMetadataMalformed,
      })
    >
  >
  pendingForAccount(String accountScope) async {
    if (!await init(requestPermissions: false)) return const [];
    final pending = await _plugin.pendingNotificationRequests();
    final result =
        <
          ({
            String id,
            String title,
            String body,
            int? hour,
            int? minute,
            HabitCadence? cadence,
            DateTime? firstScheduledLocal,
            bool cadenceMetadataMalformed,
          })
        >[];
    for (final request in pending) {
      final payload = request.payload ?? '';
      final scoped = parseAccountPayload(payload);
      if (scoped == null || scoped.accountScope != accountScope) continue;
      final metadata = jsonDecode(payload) as Map;
      final hour = metadata['dailyHour'];
      final minute = metadata['dailyMinute'];
      final hasTime =
          hour is int &&
          minute is int &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59;
      final cadenceRaw = metadata['cadence'];
      final cadence = HabitCadence.values
          .where((value) => value.name == cadenceRaw)
          .firstOrNull;
      final firstRaw = metadata['firstScheduledLocal'];
      final first = firstRaw is String ? DateTime.tryParse(firstRaw) : null;
      final validCadence =
          cadence != null &&
          hasTime &&
          first != null &&
          !first.isUtc &&
          first.toIso8601String() == firstRaw &&
          first.hour == hour &&
          first.minute == minute &&
          first.second == 0 &&
          first.millisecond == 0 &&
          first.microsecond == 0 &&
          (cadence != HabitCadence.weekly ||
              first.weekday == DateTime.monday) &&
          (cadence != HabitCadence.monthly || first.day == 1);
      result.add((
        id: scoped.notificationId,
        title: request.title ?? '',
        body: request.body ?? '',
        hour: hasTime ? hour : null,
        minute: hasTime ? minute : null,
        cadence: validCadence ? cadence : null,
        firstScheduledLocal: validCadence ? first : null,
        cadenceMetadataMalformed:
            (metadata.containsKey('cadence') ||
                metadata.containsKey('firstScheduledLocal')) &&
            !validCadence,
      ));
    }
    return result;
  }

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
    'Axiomara',
    description: 'Axiomara reminders and alerts',
    importance: Importance.high,
  );

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'chronospark_channel',
      'Axiomara',
      channelDescription: 'Axiomara reminders and alerts',
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

  @override
  Future<bool> requestPermissions() => init(requestPermissions: true);

  @override
  Future<bool> schedule(
    NotificationEntity notification, {
    String? accountScope,
  }) async {
    if (!notification.isEnabled) {
      // In-app-only entries (task completion/skip feedback and similar
      // transient toasts) are persisted for the in-app notification list but
      // must never reach the OS. Without this guard every task interaction
      // posted a real system notification one second later.
      return false;
    }
    if (!_initialized) {
      Logger.warn(
        'Skipped schedule because notification scheduler is not initialized.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule because scheduler is not initialized.',
      );
      return false;
    }
    if (!_permissionGranted) {
      Logger.log(
        'Notifications',
        'Skipped schedule because permission is not granted.',
      );
      RuntimeDiagnostics.record(
        'Skipped notification schedule because permission is not granted.',
      );
      return false;
    }
    final scheduledTz = tz.TZDateTime.from(notification.scheduledAt, tz.local);
    if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) {
      Logger.log('Notifications', 'Skipped schedule for past time.');
      RuntimeDiagnostics.record('Skipped notification schedule for past time.');
      return false;
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
    return true;
  }

  /// The actual first-date calculation used by daily reminder registration.
  @visibleForTesting
  static tz.TZDateTime nextDailyScheduledTime({
    required tz.TZDateTime now,
    required tz.Location location,
    required int hour,
    required int minute,
  }) {
    final localNow = tz.TZDateTime.from(now, location);
    var scheduled = tz.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = tz.TZDateTime(
        location,
        localNow.year,
        localNow.month,
        localNow.day + 1,
        hour,
        minute,
      );
    }
    return scheduled;
  }

  @override
  Future<bool> scheduleDailyAt({
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
      return false;
    }
    if (!_permissionGranted) {
      Logger.log(
        'Notifications',
        'Skipped daily schedule "$id" because permission is not granted.',
      );
      RuntimeDiagnostics.record(
        'Skipped daily notification schedule: permission not granted.',
      );
      return false;
    }
    final scheduled = nextDailyScheduledTime(
      now: tz.TZDateTime.now(tz.local),
      location: tz.local,
      hour: hour,
      minute: minute,
    );
    await _plugin.zonedSchedule(
      id: _notificationId(_platformKey(id, accountScope)),
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: accountScope == null
          ? id
          : accountPayload(
              accountScope,
              id,
              dailyHour: hour,
              dailyMinute: minute,
            ),
    );
    return true;
  }

  @override
  Future<bool> scheduleCadenceAt({
    required String id,
    required String title,
    required String body,
    required HabitCadence cadence,
    required DateTime firstAt,
    String? accountScope,
  }) async {
    // The bundled Android adapter preserves the explicit first-date lower
    // bound. Other adapters' repeating calendar triggers drop it, so they
    // cannot safely suppress a completed current period.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      Logger.warn('Rhythm cadence reminders are unsupported on this platform.');
      return false;
    }
    if (!_initialized || !_permissionGranted) return false;
    final local = firstAt.toLocal();
    final scheduled = tz.TZDateTime(
      tz.local,
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return false;
    final match = switch (cadence) {
      HabitCadence.daily => DateTimeComponents.time,
      HabitCadence.weekly => DateTimeComponents.dayOfWeekAndTime,
      HabitCadence.monthly => DateTimeComponents.dayOfMonthAndTime,
    };
    final payload = accountScope == null
        ? id
        : jsonEncode(<String, dynamic>{
            ...jsonDecode(
                  accountPayload(
                    accountScope,
                    id,
                    dailyHour: local.hour,
                    dailyMinute: local.minute,
                  ),
                )
                as Map<String, dynamic>,
            'cadence': cadence.name,
            'firstScheduledLocal': local.toIso8601String(),
          });
    await _plugin.zonedSchedule(
      id: _notificationId(_platformKey(id, accountScope)),
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: match,
      payload: payload,
    );
    return true;
  }

  @override
  Future<bool> cancel(String id, {String? accountScope}) async {
    // OS reminders survive process restarts. Cancellation must also work when
    // optional notification startup was skipped or failed, and needs neither
    // notification permission nor scheduling initialization.
    await _plugin.cancel(id: _notificationId(_platformKey(id, accountScope)));
    return true;
  }

  @override
  Future<bool> cancelAll() async {
    await _plugin.cancelAll();
    return true;
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

  static String accountPayload(
    String accountScope,
    String notificationId, {
    int? dailyHour,
    int? dailyMinute,
  }) {
    return jsonEncode(<String, Object>{
      'v': 1,
      'accountScope': accountScope,
      'notificationId': notificationId,
      if (dailyHour != null && dailyMinute != null) 'dailyHour': dailyHour,
      if (dailyHour != null && dailyMinute != null) 'dailyMinute': dailyMinute,
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
