import 'dart:async';

import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
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

@immutable
class NotificationPermissionSnapshot {
  const NotificationPermissionSnapshot({
    required this.granted,
    required this.permissionState,
  });

  final bool? granted;
  final NotificationPermissionState permissionState;

  bool get isGranted => granted == true;

  const NotificationPermissionSnapshot.unknown()
    : granted = null,
      permissionState = NotificationPermissionState.unknown;
}

class NotificationPermissionNotifier
    extends Notifier<NotificationPermissionSnapshot> {
  ReflectionReminderService get _reminderService {
    return ref.read(reflectionReminderServiceProvider);
  }

  @override
  NotificationPermissionSnapshot build() {
    final bool? granted = _reminderService.permissionListenable.value;
    unawaited(refresh());
    return NotificationPermissionSnapshot(
      granted: granted,
      permissionState: granted == null
          ? NotificationPermissionState.unknown
          : (granted
                ? NotificationPermissionState.granted
                : NotificationPermissionState.denied),
    );
  }

  Future<NotificationPermissionSnapshot> requestPermission() async {
    await _reminderService.requestNotificationPermissionDetailed();
    return refresh();
  }

  Future<NotificationPermissionSnapshot> refresh() async {
    final bool? granted = _reminderService.permissionListenable.value;
    final NotificationPermissionState permissionState = await _reminderService
        .getNotificationPermissionState();
    final NotificationPermissionSnapshot snapshot =
        NotificationPermissionSnapshot(
          granted: granted,
          permissionState: permissionState,
        );
    state = snapshot;
    return snapshot;
  }
}

final notificationPermissionProvider =
    NotifierProvider<
      NotificationPermissionNotifier,
      NotificationPermissionSnapshot
    >(NotificationPermissionNotifier.new);

class VoicePermissionStatusNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool value) => state = value;
}

final voicePermissionStatusProvider =
    NotifierProvider<VoicePermissionStatusNotifier, bool?>(
      VoicePermissionStatusNotifier.new,
    );
