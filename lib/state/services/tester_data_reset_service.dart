import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';

class TesterDataResetService {
  const TesterDataResetService({
    required this._preferences,
    required this._hive,
    required this._secureStore,
    this._sensitivePreferences,
  });

  final SharedPrefsStore _preferences;
  final HiveStore _hive;
  final SecureStore _secureStore;
  final SharedPrefsStore? _sensitivePreferences;

  static const List<String> hiveBoxes = <String>[
    'tasks_box',
    'profile_box',
    'flowmap_box',
    'tasks',
    StorageKeys.credentials,
    StorageKeys.session,
    StorageKeys.identity,
    StorageKeys.notifications,
    StorageKeys.theme,
    StorageKeys.settings,
  ];

  // Keep this allowlist explicit. A blanket secure-storage deletion would also
  // remove Hive's encryption key and could strand encrypted local databases.
  static const List<String> secureKeys = <String>[
    'identity_id',
    'si_engine_state_v1',
    'workspace_creator_v1',
    'workspace_temporal_v1',
    'workspace_si_v1',
    'chronologs_payload_v1',
    'ai_learning',
    'neural_dump',
    'settings_v1_neon_recall',
    'settings_v1_si_module',
    'settings_v1_notifications',
    'settings_v1_analytics_sharing',
    'settings_v1_data_sync',
    'settings_v1_compact_mode',
    'settings_v1_text_scale',
    'settings_v1_si_tuning',
    'task_entries_v2',
    'flowmap_entries_v2',
    'profile_state_v2',
    'paywall_subscription_state_v1',
  ];

  Future<void> reset() async {
    await _hive.init();
    for (final String box in hiveBoxes) {
      await _hive.clearBox(box);
    }

    for (final String key in secureKeys) {
      await _secureStore.delete(key);
    }

    await _preferences.clear();
    await _sensitivePreferences?.clear();
  }
}
