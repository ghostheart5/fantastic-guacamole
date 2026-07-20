import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';

class LocalUserDataCleanupService {
  const LocalUserDataCleanupService({
    required this.preferences,
    required this.hive,
    required this.secureStore,
  });

  final SharedPrefsStore preferences;
  final HiveStore hive;
  final SecureStore secureStore;

  static const List<String> _hiveBoxes = <String>[
    HiveBoxes.tasks,
    HiveBoxes.goals,
    HiveBoxes.routines,
    HiveBoxes.projects,
    HiveBoxes.subtasks,
    HiveBoxes.progression,
    HiveBoxes.dailyPlans,
    HiveBoxes.flowmap,
    HiveBoxes.timeline,
    HiveBoxes.offlineQueue,
    'profile_box',
  ];

  static const List<String> _secureKeys = <String>[
    'auth.cached_session',
    'identity_id',
    'identity_profile_v1',
    'profile_entity_v1',
    'profile_state_v2',
    'sessions_entity_v1',
    'chrono_log_entries_v2',
    'milestones_v1',
    'si_engine_state_v1',
    'si_decision_snapshot_v1',
    'paywall_subscription_state_v1',
    'workspace_creator_v1',
    'workspace_temporal_v1',
    'workspace_si_v1',
  ];

  static const List<String> _prefsKeys = <String>[
    'emotion_state_v1',
    'user_preferences_json',
    'settings_entity_v1',
    'app_theme_entity_v1',
    'primary_goal_type',
    'rec_last_route',
    'rec_active_task',
    'rec_draft_title',
  ];

  Future<void> clear({String? userId}) async {
    await preferences.init();
    await hive.init();

    final List<Future<void> Function()> steps = <Future<void> Function()>[
      for (final String box in _hiveBoxes) () => hive.clearBox(box),
      for (final String key in _secureKeys) () => secureStore.delete(key),
      for (final String key in _prefsKeys) () => preferences.delete(key),
      () => preferences.delete(onboardingCompleteStorageKey),
      () => preferences.delete(onboardingContentVersionStorageKey),
      () => preferences.delete(onboardingStepStorageKey),
      () => preferences.delete('onboarding_state_v1'),
    ];

    if (userId != null && userId.trim().isNotEmpty) {
      steps.addAll(<Future<void> Function()>[
        () => preferences.delete(onboardingCompleteStorageKeyForUser(userId)),
        () => preferences.delete(
          onboardingContentVersionStorageKeyForUser(userId),
        ),
        () => preferences.delete(onboardingStepStorageKeyForUser(userId)),
        () => preferences.delete('onboarding_state_v1_$userId'),
      ]);
    }

    for (final Future<void> Function() step in steps) {
      try {
        await step();
      } on Object catch (error) {
        Logger.warn('Local user data cleanup step failed: $error');
      }
    }
  }
}