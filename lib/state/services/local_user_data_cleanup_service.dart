import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/notifications_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
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
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _mutations = mutationCoordinator ?? KeyedMutationCoordinator.shared;

  final HiveStore _hive;
  final SecureStore _secureStore;
  final SharedPrefsStore _preferences;
  final SharedPrefsStore _sensitivePreferences;
  final NotificationScheduler _notifications;
  final KeyedMutationCoordinator _mutations;

  Future<void> clearForAccountSwitch([String? accountId]) async {
    return runAccountStorageMutation(
      () => _clearForAccountSwitch(accountId),
      coordinator: _mutations,
    );
  }

  Future<void> _clearForAccountSwitch(String? accountId) async {
    final String? requestedAccountId = _normalizedAccountId(accountId);
    final String? storedAccountId = _normalizedAccountId(
      await _secureStore.readString(
        AccountDataRegistry.accountBoundaryOwnerKey,
      ),
    );
    final String? departingAccountId = requestedAccountId ?? storedAccountId;
    final bool includeLegacyOwnedData =
        departingAccountId != null && departingAccountId == storedAccountId;
    if (departingAccountId != null) {
      await NotificationsRepository(
        _notifications,
        _secureStore,
        accountId: departingAccountId,
        mutationCoordinator: _mutations,
      ).clearAccountData(includeLegacyOwnedData: includeLegacyOwnedData);
    } else {
      await _notifications.cancelAll();
      NotificationScheduler.tappedPayloadListenable.value = null;
    }

    await _hive.init();
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor(
          departingAccountId,
          includeLegacyOwnedData: includeLegacyOwnedData,
        );
    for (final String box in cleanupPlan.hiveBoxes) {
      await _hive.clearBox(box);
    }

    for (final String key in cleanupPlan.secureExactKeys) {
      await _secureStore.delete(key);
    }
    if (cleanupPlan.secureKeyPrefixes.isNotEmpty) {
      await _deleteMatchingSecureKeys(cleanupPlan.secureKeyPrefixes);
    }
    if (departingAccountId != null) {
      await _secureStore
          .forAccount(AccountStorageScope.authenticated(departingAccountId))
          .deleteAll();
    }

    await _sensitivePreferences.init();
    for (final String key in cleanupPlan.sensitivePreferenceKeys) {
      await _sensitivePreferences.delete(key);
    }
    if (includeLegacyOwnedData) {
      if (_sensitivePreferences case final CorruptionBackupStore recoverable) {
        await recoverable.clearCorruptionBackups();
      }
    }
    if (departingAccountId != null) {
      await AccountScopedSharedPrefsStore(
        delegate: _sensitivePreferences,
        scope: AccountStorageScope.authenticated(departingAccountId),
      ).clear();
    }

    for (final String key in cleanupPlan.preferenceExactKeys) {
      await _preferences.delete(key);
    }
    if (cleanupPlan.preferenceKeyPrefixes.isNotEmpty) {
      await _deleteMatchingPreferenceKeys(cleanupPlan.preferenceKeyPrefixes);
    }
    if (departingAccountId != null) {
      await AccountScopedSharedPrefsStore(
        delegate: _preferences,
        scope: AccountStorageScope.authenticated(departingAccountId),
      ).clear();
    }
  }

  /// Detects legacy account data whose owner cannot be proven because no
  /// account marker exists. Device-wide theme/onboarding/identity keys are
  /// intentionally excluded.
  Future<bool> hasUnownedAccountData() async {
    final AccountDataCleanupPlan cleanupPlan =
        AccountDataRegistry.cleanupPlanFor(null);
    await _hive.init();
    for (final String boxName in cleanupPlan.hiveBoxes) {
      final bool wasOpen = _hive.isBoxOpen(boxName);
      // Every account-owned Hive repository serializes its payload as JSON
      // strings. Opening an already-open Box<String> as Box<dynamic> throws
      // before ownership recovery can be offered.
      final box = await _hive.openBox<String>(boxName);
      final bool hasValues = box.isNotEmpty;
      if (!wasOpen) await box.close();
      if (hasValues) return true;
    }
    for (final String key in cleanupPlan.secureExactKeys) {
      if (await _secureStore.readString(key) != null) return true;
    }
    await _sensitivePreferences.init();
    if (_sensitivePreferences case final CorruptionBackupStore recoverable) {
      if (recoverable.hasCorruptionBackups) return true;
    }
    for (final String key in cleanupPlan.sensitivePreferenceKeys) {
      if (_sensitivePreferences.load(key) != null) return true;
    }
    for (final String key in cleanupPlan.preferenceExactKeys) {
      if (await SharedPrefsService.contains(key)) return true;
    }
    return false;
  }

  Future<void> _deleteMatchingSecureKeys(Set<String> prefixes) async {
    final Set<String> keys = (await _secureStore.readAll()).keys.toSet();
    for (final String key in keys) {
      if (prefixes.any(key.startsWith)) await _secureStore.delete(key);
    }
  }

  Future<void> _deleteMatchingPreferenceKeys(Set<String> prefixes) async {
    final EnumerableSharedPrefsStore? enumerable =
        _preferences is EnumerableSharedPrefsStore
        ? _preferences as EnumerableSharedPrefsStore
        : null;
    if (enumerable == null) return;
    final Set<String> keys = await enumerable.keys();
    for (final String key in keys) {
      if (prefixes.any(key.startsWith)) await _preferences.delete(key);
    }
  }

  String? _normalizedAccountId(String? accountId) {
    final String normalized = accountId?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
