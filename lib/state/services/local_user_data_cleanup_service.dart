import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

/// Removes account-owned state before another account can use this device.
/// App-wide onboarding/theme preferences intentionally remain intact.
class LocalUserDataCleanupService {
  LocalUserDataCleanupService({
    required this._hive,
    required this._secureStore,
    required this._sensitivePreferences,
    required this._notifications,
  });

  final HiveStore _hive;
  final SecureStore _secureStore;
  final SharedPrefsStore _sensitivePreferences;
  final NotificationScheduler _notifications;

  static const List<String> _userBoxes = <String>[
    HiveBoxes.tasks,
    HiveBoxes.goals,
    HiveBoxes.habits,
    HiveBoxes.projects,
    HiveBoxes.routines,
    HiveBoxes.subtasks,
    HiveBoxes.progression,
    HiveBoxes.dailyPlans,
    HiveBoxes.offlineQueue,
    HiveBoxes.notifications,
    HiveBoxes.timeline,
    'profile_box',
  ];

  static const List<String> _userSecureKeys = <String>[
    'identity_id',
    'si_engine_state_v1',
    'workspace_creator_v1',
    'workspace_temporal_v1',
    'workspace_si_v1',
    'timeline_payload_v1',
    'ai_learning',
    'neural_dump',
    'profile_state_v2',
    'paywall_subscription_state_v1',
    'bridge.firebase_messaging_token',
    'cloud_backup_encryption_key_v1',
  ];

  static const List<String> _userPreferenceKeys = <String>[
    'user_preferences_json',
    'personalization_profile_v1',
    'observed_planning_patterns_v1',
    'profile_values',
    'soul_map_profile_v1',
    'behavior_state_v1',
    'global_metrics_cache',
    'global_metrics_cache_ts',
    'last_route',
    'active_task_id',
    'draft_task_title',
    'primary_goal_type',
  ];

  Future<void> clearForAccountSwitch() async {
    await _hive.init();
    for (final String box in _userBoxes) {
      await _hive.clearBox(box);
    }
    for (final String key in _userSecureKeys) {
      await _secureStore.delete(key);
    }
    for (final String key in _userPreferenceKeys) {
      await _sensitivePreferences.delete(key);
    }
    await SharedPrefsService.delete('last_opened_tab');
    await _notifications.cancelAll();
  }
}
