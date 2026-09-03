import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fail-closed account-owned storage views for consumers that do not own their
/// own namespace protocol.
final accountSecureStoreProvider = Provider<SecureStore>((Ref ref) {
  return ref
      .read(secureStoreProvider)
      .forAccount(
        ref.watch(accountStorageScopeProvider),
        legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
      );
});

final accountSharedPrefsStoreProvider = Provider<SharedPrefsStore>((Ref ref) {
  return AccountScopedSharedPrefsStore(
    delegate: ref.read(sharedPrefsStoreProvider),
    scope: ref.watch(accountStorageScopeProvider),
    legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
  );
});

final accountSensitivePrefsStoreProvider = Provider<SharedPrefsStore>((
  Ref ref,
) {
  return AccountScopedSharedPrefsStore(
    delegate: ref.read(sensitivePrefsStoreProvider),
    scope: ref.watch(accountStorageScopeProvider),
    legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
  );
});

/// Keeps device-wide onboarding separate from account-owned navigation and
/// user preferences.
final preferenceServiceProvider = Provider<PreferenceService>((Ref ref) {
  return PreferenceService(
    deviceStore: ref.read(sharedPrefsStoreProvider),
    accountStore: ref.watch(accountSharedPrefsStoreProvider),
  );
});
