import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
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

  static const Set<String> hiveBoxes = <String>{
    ...AccountDataRegistry.legacyAccountHiveBoxes,
    StorageKeys.theme,
    StorageKeys.settings,
  };

  // Keep this allowlist explicit. A blanket secure-storage deletion would also
  // remove Hive's encryption key and could strand encrypted local databases.
  static const Set<String> secureKeys =
      AccountDataRegistry.accountSecureExactKeys;

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
