import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';

class CacheCleanupService {
  const CacheCleanupService({
    required this._preferences,
    required this._hive,
    required this._secureStore,
  });

  final SharedPrefsStore _preferences;
  final HiveStore _hive;
  final SecureStore _secureStore;

  static const List<String> _prefsCacheKeys = <String>[
    'debug_last_screen',
    'pending_deep_link_v1',
    'recent_permission_prompt_cache',
  ];

  static const List<String> _secureCacheKeys = <String>[
    'workspace_sync_cache_v1',
    'ai_runtime_cache_v1',
  ];

  static const List<String> _hiveCacheBoxes = <String>[
    'test_cache',
    'unit_test_assets',
  ];

  Future<int> run() async {
    int removed = 0;

    await _preferences.init();
    await _hive.init();

    for (final String key in _prefsCacheKeys) {
      if (_preferences.load(key) != null) {
        await _preferences.delete(key);
        removed++;
      }
    }

    for (final String key in _secureCacheKeys) {
      final String? existing = await _secureStore.readString(key);
      if (existing != null) {
        await _secureStore.delete(key);
        removed++;
      }
    }

    for (final String box in _hiveCacheBoxes) {
      if (_hive.isBoxOpen(box)) {
        await _hive.clearBox(box);
        removed++;
      }
    }

    return removed;
  }
}
