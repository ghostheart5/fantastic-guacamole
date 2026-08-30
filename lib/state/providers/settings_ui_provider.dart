import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/services/backup_cipher.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/services/reflection_reminder_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/location/location_service.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// The only user-facing entry point that can request remote push permission.
  /// Local scheduling permission remains explicit as well; startup never calls
  /// either operating-system prompt.
  Future<bool> requestNotificationPermissionAndRegisterPush() async {
    final bool localGranted = await requestNotificationPermission();
    if (!localGranted) {
      return false;
    }
    final String? issue = await const FirebaseMessagingBootstrap()
        .requestPermissionAndToken(isMockMode: Env.isMockMode);
    if (issue != null) {
      // Local reminders remain enabled when remote push registration is
      // unavailable on a platform or during a transient backend outage.
      return localGranted;
    }
    final String? token = FirebaseMessagingBootstrap.latestToken;
    final client = _ref.read(supabaseClientProvider);
    if (token != null && token.isNotEmpty && client != null) {
      try {
        await _ref
            .read(firebaseSupabaseBridgeRepositoryProvider)
            .syncFirebaseMessagingToken(client, token, source: 'settings');
      } on Object {
        // Permission remains granted even if cloud token sync is temporarily
        // unavailable; the bridge retries on a later authenticated refresh.
      }
    }
    return true;
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

  Future<AppLocationResult> requestLocationPermissionAndCurrentLocation() {
    return _ref
        .read(appLocationServiceProvider)
        .requestPermissionAndCurrentLocation();
  }

  Future<bool> openLocationAppSettings() {
    return _ref.read(appLocationServiceProvider).openAppSettings();
  }

  Future<bool> openLocationSystemSettings() {
    return _ref.read(appLocationServiceProvider).openLocationSettings();
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

  Future<String> exportBackupRecoveryKey() {
    return _backupCipher().exportRecoveryKey();
  }

  Future<void> importBackupRecoveryKey(String recoveryKey) {
    return _backupCipher().importRecoveryKey(recoveryKey);
  }

  BackupCipher _backupCipher() {
    final scope = _ref.read(accountStorageScopeProvider);
    return BackupCipher(
      _ref.read(secureStoreProvider),
      accountId: scope.isWritable ? scope.rawUserId : null,
    );
  }
}

final settingsUiActionsProvider = Provider<SettingsUiActions>((Ref ref) {
  return SettingsUiActions(ref);
});

const String _cloudSyncPreferenceKey = 'cloud_sync_enabled_v1';

class CloudSyncPreferenceNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Cloud transfer is opt-in. A build flag only makes the capability
    // available; it must not silently allow data transfer.
    return prefs.getBool(_cloudSyncPreferenceKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData<bool>(enabled);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudSyncPreferenceKey, enabled);
    if (!enabled) {
      await SharedPrefsService.delete('global_metrics_cache');
      await SharedPrefsService.delete('global_metrics_cache_ts');
    }
  }
}

final cloudSyncPreferenceProvider =
    AsyncNotifierProvider<CloudSyncPreferenceNotifier, bool>(
      CloudSyncPreferenceNotifier.new,
    );

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

final appLocationServiceProvider = Provider<AppLocationService>((Ref ref) {
  return const AppLocationService();
});

class LocationPermissionStatusNotifier extends Notifier<AppLocationResult?> {
  @override
  AppLocationResult? build() => null;

  void set(AppLocationResult result) => state = result;
}

final locationPermissionStatusProvider =
    NotifierProvider<LocationPermissionStatusNotifier, AppLocationResult?>(
      LocationPermissionStatusNotifier.new,
    );
