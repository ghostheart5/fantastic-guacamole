import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';

class OrphanDataCleanup {
  const OrphanDataCleanup({
    required this._preferences,
    required this._secureStore,
  });

  final SharedPrefsStore _preferences;
  final SecureStore _secureStore;

  static const List<String> _orphanPrefsKeys = <String>[
    'legacy_onboarding_step',
    'legacy_route_override',
    'deprecated_theme_seed',
  ];

  static const List<String> _orphanSecureKeys = <String>[
    'si_engine_state_legacy',
    'legacy_workspace_payload',
    'deprecated_session_shadow',
  ];

  Future<int> run() async {
    int removed = 0;
    await _preferences.init();

    for (final String key in _orphanPrefsKeys) {
      if (_preferences.load(key) != null) {
        await _preferences.delete(key);
        removed++;
      }
    }

    for (final String key in _orphanSecureKeys) {
      final String? value = await _secureStore.readString(key);
      if (value != null) {
        await _secureStore.delete(key);
        removed++;
      }
    }

    return removed;
  }
}
