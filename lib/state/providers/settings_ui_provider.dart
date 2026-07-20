import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsUiActions {
  SettingsUiActions(this._ref);

  static final ValueNotifier<NotificationPermissionState>
  _notificationPermissionStateListenable =
      ValueNotifier<NotificationPermissionState>(
        NotificationPermissionState.unknown,
      );

  final Ref _ref;

  ReflectionReminderService get _reminderService {
    return _ref.read(reflectionReminderServiceProvider);
  }

  ReflectionReminderPrefs loadReflectionReminderPrefs() {
    return _reminderService.loadPrefs();
  }

  Future<bool> setReflectionReminderEnabled({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    return _reminderService.setEnabled(enabled: enabled, time: time);
  }

  Future<void> setReflectionReminderTime({required TimeOfDay time}) async {
    await _reminderService.setTime(time: time);
  }

  Future<bool> requestNotificationPermission() {
    return requestNotificationPermissionDetailed().then(
      (NotificationPermissionState state) =>
          state == NotificationPermissionState.granted,
    );
  }

  ValueListenable<NotificationPermissionState>
  get notificationPermissionStateListenable {
    return _notificationPermissionStateListenable;
  }

  Future<NotificationPermissionState> requestNotificationPermissionDetailed() async {
    final NotificationPermissionState state =
        await _reminderService.requestNotificationPermissionDetailed();
    _notificationPermissionStateListenable.value = state;
    return state;
  }

  Future<NotificationPermissionState> refreshNotificationPermissionState() async {
    final NotificationPermissionState state =
        await _reminderService.getNotificationPermissionState();
    _notificationPermissionStateListenable.value = state;
    return state;
  }

  ReminderOrchestratorPrefs loadAdvancedReminderPrefs() {
    return _ref.read(reminderOrchestratorServiceProvider).loadPrefs();
  }

  Future<void> setGoalRemindersEnabled(bool enabled) async {
    await _ref
        .read(reminderOrchestratorServiceProvider)
        .setGoalRemindersEnabled(enabled);
  }

  Future<void> setHabitRemindersEnabled(bool enabled) async {
    await _ref
        .read(reminderOrchestratorServiceProvider)
        .setHabitRemindersEnabled(enabled);
  }

  Future<void> setDailyPlanningReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    await _ref
        .read(reminderOrchestratorServiceProvider)
        .setDailyPlanningReminder(
          enabled: enabled,
          hour: time.hour,
          minute: time.minute,
        );
  }

  Future<bool> requestVoicePermission() async {
    return _ref.read(voicePermissionServiceProvider).requestPermission();
  }

  Future<bool> openSystemAppSettings() async {
    final external = _ref.read(externalUrlServiceProvider);
    const List<String> candidates = <String>['app-settings:', 'App-Prefs:root'];

    for (final String uri in candidates) {
      final bool opened = await external.open(Uri.parse(uri));
      if (opened) {
        return true;
      }
    }
    return false;
  }
}

final settingsUiActionsProvider = Provider<SettingsUiActions>((Ref ref) {
  return SettingsUiActions(ref);
});

final notificationPermissionListenableProvider =
    Provider<ValueListenable<bool?>>((ref) {
      return ref.read(reflectionReminderServiceProvider).permissionListenable;
    });

final notificationPermissionStateListenableProvider =
    Provider<ValueListenable<NotificationPermissionState>>((ref) {
      final SettingsUiActions actions = ref.read(settingsUiActionsProvider);
      return actions.notificationPermissionStateListenable;
    });

class VoicePermissionStatusNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool value) => state = value;
}

final voicePermissionStatusProvider =
    NotifierProvider<VoicePermissionStatusNotifier, bool?>(
      VoicePermissionStatusNotifier.new,
    );
