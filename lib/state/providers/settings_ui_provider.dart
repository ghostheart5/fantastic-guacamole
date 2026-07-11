import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsUiActions {
  SettingsUiActions(this._ref);

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
    return _reminderService.requestNotificationPermission();
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

class VoicePermissionStatusNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool value) => state = value;
}

final voicePermissionStatusProvider =
    NotifierProvider<VoicePermissionStatusNotifier, bool?>(
      VoicePermissionStatusNotifier.new,
    );
