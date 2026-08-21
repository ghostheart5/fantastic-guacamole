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
    required this._preferences,
    required this._sensitivePreferences,
    required this._notifications,
  });

  final HiveStore _hive;
  final SecureStore _secureStore;
  final SharedPrefsStore _preferences;
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
    'identity_profile_v1',
    'si_engine_state_v1',
    'workspace_entity_v1',
    'workspace_creator_v1',
    'workspace_temporal_v1',
    'workspace_si_v1',
    'timeline_payload_v1',
    'ai_learning',
    'learning_state_v1',
    'neural_dump',
    'profile_state_v2',
    'profile_entity_v1',
    'paywall_subscription_state_v1',
    'entitlement_owner_user_id_v1',
    'bridge.firebase_messaging_token',
    'notification_entries_v1',
    'chrono_log_entries_v2',
    'calendar_entries_v1',
    'milestones_v1',
    'creator_latest_receipt_v1:local',
    'auth_session_box',
    'auth_credentials_box',
  ];

  static const List<String> _userSensitivePreferenceKeys = <String>[
    'memories_v1',
    'timeline_events_v1',
    'goals_v1',
    'goals_v2',
  ];

  static const List<String> _userPreferenceKeys = <String>[
    'user_preferences_json',
    'personalization_profile_v1',
    'observed_planning_patterns_v1',
    'behavior_state_v1',
    'signals_v1',
    'ins'
        'ights_v1',
    'notes_v1',
    'settings_entity_v1',
    'ai_credit_wallet',
    'self_opt_config_v1',
    'self_opt_last_adjust',
    'cloud_sync_enabled_v1',
    'goal_reminders_enabled',
    'habit_reminders_enabled',
    'daily_planning_reminder_enabled',
    'daily_planning_reminder_time',
    'reflection_reminder_enabled',
    'reflection_reminder_time',
    'global_metrics_cache',
    'global_metrics_cache_ts',
    'lma_date',
    'lma_tasks_created',
    'lma_tasks_completed',
    'lma_momentum_peak',
    'rec_last_route',
    'rec_active_task',
    'rec_draft_title',
    'last_route',
    'active_task_id',
    'draft_task_title',
    'primary_goal_type',
    'offline_sync_queue_v1',
    'paywall_auto_restore_prompted_v1',
    'paywall_subscription_state_v1',
    'settings',
    'local_test_cloud_backup',
    'local_test_cloud_tasks',
    'extended_domain.coach_messages',
    'extended_domain.planner_messages',
    'extended_domain.si_queries',
    'extended_domain.user_intents',
    'extended_domain.reflection_entries',
    'extended_domain.'
        'jour'
        'nal_entries',
    'extended_domain.analytics_metrics',
    'extended_domain.app_notifications',
    'extended_domain.rewards',
    'extended_domain.settings',
    'extended_domain.sync_states',
    'extended_domain.offline_states',
    'extended_domain.app_errors',
    'extended_domain.recovery_states',
  ];

  Future<void> clearForAccountSwitch() async {
    await _hive.init();
    for (final String boxName in _userBoxes) {
      final bool wasOpen = _hive.isBoxOpen(boxName);
      final box = await _hive.openBox<String>(boxName);
      await box.clear();
      if (!wasOpen) await box.close();
    }
    for (final String key in _userSecureKeys) {
      await _secureStore.delete(key);
    }
    await _sensitivePreferences.clear();
    for (final String key in _userPreferenceKeys) {
      await _preferences.delete(key);
    }
    await _notifications.cancelAll();
  }

  /// Detects legacy account data whose owner cannot be proven because no
  /// account marker exists. Device-wide theme/onboarding/identity keys are
  /// intentionally excluded.
  Future<bool> hasUnownedAccountData() async {
    await _hive.init();
    for (final String boxName in _userBoxes) {
      final bool wasOpen = _hive.isBoxOpen(boxName);
      // Every account-owned Hive repository serializes its payload as JSON
      // strings. Opening an already-open Box<String> as Box<dynamic> throws
      // before ownership recovery can be offered.
      final box = await _hive.openBox<String>(boxName);
      final bool hasValues = box.isNotEmpty;
      if (!wasOpen) await box.close();
      if (hasValues) return true;
    }
    for (final String key in _userSecureKeys) {
      if (await _secureStore.readString(key) != null) return true;
    }
    await _sensitivePreferences.init();
    for (final String key in _userSensitivePreferenceKeys) {
      if (_sensitivePreferences.load(key) != null) return true;
    }
    for (final String key in _userPreferenceKeys) {
      if (await SharedPrefsService.contains(key)) return true;
    }
    return false;
  }
}
