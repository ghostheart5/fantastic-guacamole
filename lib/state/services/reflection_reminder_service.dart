import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
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
    this.hasMatchingRegistration,
  });

  static const String enabledKey = 'reflection_reminder_enabled';
  static const String timeKey = 'reflection_reminder_time';
  static const String notificationId = 'reflection_reminder';

  /// The account's main reminder switch (see
  /// `ReminderOrchestratorService.remindersEnabledKey`); missing means on.
  static const String remindersEnabledKey = 'reminders_enabled';

  bool get _remindersOn {
    final String? raw = _preferences.load(remindersEnabledKey);
    return raw == null || raw == 'true';
  }

  final SharedPrefsStore _preferences;
  final NotificationSchedulerPort _scheduler;
  final ValueListenable<bool?> permissionListenable;
  final String? _accountScope;
  final Future<bool> Function(TimeOfDay time)? hasMatchingRegistration;

  Future<T> _mutate<T>(Future<T> Function() action) =>
      KeyedMutationCoordinator.shared.runExclusive<T>(
        AccountDataRegistry.notificationMutationKeyForScope(
          _accountScope ?? 'legacy',
        ),
        action,
      );

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

  Future<bool> setEnabled({required bool enabled, required TimeOfDay time}) =>
      _mutate(() async {
        await _preferences.save(enabledKey, 'false');
        await _preferences.save(timeKey, '${time.hour}:${time.minute}');

        if (!enabled) {
          await _scheduler.cancel(notificationId, accountScope: _accountScope);
          return false;
        }
        if (!_remindersOn) {
          // Kept for when the main reminder switch is turned back on.
          await _preferences.save(enabledKey, 'true');
          return true;
        }

        // Never asks here: the switch asks first, once, through the shared
        // in-context permission helper. Missing permission reports false.
        final result = await _scheduler.scheduleDailyAt(
          id: notificationId,
          title: 'Daily Reflection',
          body:
              'Take 3 minutes to review your day and set intent for tomorrow.',
          hour: time.hour,
          minute: time.minute,
          accountScope: _accountScope,
        );
        final scheduled = result == NotificationScheduleResult.scheduled;
        await _preferences.save(enabledKey, scheduled.toString());
        if (!scheduled) {
          await _scheduler.cancel(notificationId, accountScope: _accountScope);
        }
        return scheduled;
      });

  Future<bool> setTime({required TimeOfDay time}) => _mutate(() async {
    await _preferences.save(timeKey, '${time.hour}:${time.minute}');
    if (!loadPrefs().enabled || !_remindersOn) return true;
    final result = await _scheduler.scheduleDailyAt(
      id: notificationId,
      title: 'Daily Reflection',
      body: 'Take 3 minutes to review your day and set intent for tomorrow.',
      hour: time.hour,
      minute: time.minute,
      accountScope: _accountScope,
    );
    final scheduled = result == NotificationScheduleResult.scheduled;
    if (!scheduled) {
      await _preferences.save(enabledKey, 'false');
      await _scheduler.cancel(notificationId, accountScope: _accountScope);
    }
    return scheduled;
  });

  Future<bool> requestNotificationPermission() {
    return _scheduler.requestPermissions();
  }

  /// Restore never requests permission or changes the restored preference.
  Future<bool> reconcileAfterRestore({
    required bool permissionGranted,
    required bool Function() shouldContinue,
  }) => KeyedMutationCoordinator.shared.runExclusive<bool>(
    AccountDataRegistry.notificationMutationKeyForScope(
      _accountScope ?? 'legacy',
    ),
    () async {
      if (!shouldContinue()) return false;
      final prefs = loadPrefs();
      // The main reminder switch off keeps the choice but no OS reminder.
      final bool wanted = prefs.enabled && _remindersOn;
      // An inexact daily alarm may still be waiting to fire after its nominal
      // minute. Preserve that occurrence (and any posted notification) when
      // this account already has the requested daily registration.
      if (wanted && permissionGranted && hasMatchingRegistration != null) {
        final matches = await hasMatchingRegistration!(prefs.time);
        if (!shouldContinue()) return false;
        if (matches) return true;
      }
      if (!await _scheduler.cancel(
        notificationId,
        accountScope: _accountScope,
      )) {
        return false;
      }
      if (!shouldContinue()) return false;
      if (!wanted) return true;
      if (!permissionGranted) return false;
      final result = await _scheduler.scheduleDailyAt(
        id: notificationId,
        title: 'Daily Reflection',
        body: 'Take 3 minutes to review your day and set intent for tomorrow.',
        hour: prefs.time.hour,
        minute: prefs.time.minute,
        accountScope: _accountScope,
      );
      final scheduled = result == NotificationScheduleResult.scheduled;
      if (!shouldContinue()) {
        await _scheduler.cancel(notificationId, accountScope: _accountScope);
        return false;
      }
      return scheduled;
    },
  );
}

class VoicePermissionService {
  const VoicePermissionService();

  Future<bool> requestPermission() async {
    try {
      final PermissionStatus status = await Permission.microphone.request();
      return status.isGranted;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.voicePermissionRequestUnavailable,
        debugMessage: 'Microphone permission request is unavailable.',
        exception: error,
        stackTrace: stackTrace,
      );
      return false;
    } catch (_) {
      return false;
    }
  }
}
