import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';

class TesterDataResetService {
  const TesterDataResetService({
    required this._preferences,
    required this._hive,
    required this._secureStore,
    required this.scope,
    this.legacyOwnership = LegacyScopeOwnership.ambiguous,
    this._sensitivePreferences,
  });

  final SharedPrefsStore _preferences;
  final HiveStore _hive;
  final SecureStore _secureStore;
  final SharedPrefsStore? _sensitivePreferences;
  final AccountStorageScope scope;
  final LegacyScopeOwnership legacyOwnership;

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
    final String? accountId = scope.rawUserId;
    if (!scope.isWritable || accountId == null) {
      throw StateError('Tester data reset requires an authenticated account.');
    }
    final bool includeLegacyOwnedData =
        legacyOwnership == LegacyScopeOwnership.provenOwned;
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor(
          accountId,
          includeLegacyOwnedData: includeLegacyOwnedData,
        );

    await _hive.init();
    for (final String box in <String>{
      ...cleanupPlan.hiveBoxes,
      StorageKeys.theme,
      StorageKeys.settings,
    }) {
      await _hive.clearBox(box);
    }

    for (final String key in cleanupPlan.secureExactKeys) {
      await _secureStore.delete(key);
    }
    await _deleteMatchingSecureKeys(cleanupPlan.secureKeyPrefixes);
    await _secureStore.forAccount(scope).deleteAll();

    for (final String key in <String>{
      ...cleanupPlan.preferenceExactKeys,
      ...AccountDataRegistry.deviceGlobalPreferenceKeys,
    }) {
      await _preferences.delete(key);
    }
    await _deleteMatchingPreferenceKeys(
      _preferences,
      cleanupPlan.preferenceKeyPrefixes,
    );
    await AccountScopedSharedPrefsStore(
      delegate: _preferences,
      scope: scope,
    ).clear();

    final SharedPrefsStore? sensitivePreferences = _sensitivePreferences;
    if (sensitivePreferences != null) {
      for (final String key in cleanupPlan.sensitivePreferenceKeys) {
        await sensitivePreferences.delete(key);
      }
      if (includeLegacyOwnedData) {
        if (sensitivePreferences case CorruptionBackupStore recoverable) {
          await recoverable.clearCorruptionBackups();
        }
      }
      await AccountScopedSharedPrefsStore(
        delegate: sensitivePreferences,
        scope: scope,
      ).clear();
    }
  }

  Future<void> _deleteMatchingSecureKeys(Set<String> prefixes) async {
    if (prefixes.isEmpty) return;
    final Set<String> keys = (await _secureStore.readAll()).keys.toSet();
    for (final String key in keys) {
      if (prefixes.any(key.startsWith)) await _secureStore.delete(key);
    }
  }

  Future<void> _deleteMatchingPreferenceKeys(
    SharedPrefsStore store,
    Set<String> prefixes,
  ) async {
    if (prefixes.isEmpty) return;
    final EnumerableSharedPrefsStore? enumerable =
        store is EnumerableSharedPrefsStore
        ? store as EnumerableSharedPrefsStore
        : null;
    if (enumerable == null) return;
    final Set<String> keys = await enumerable.keys();
    for (final String key in keys) {
      if (prefixes.any(key.startsWith)) await store.delete(key);
    }
  }
}
