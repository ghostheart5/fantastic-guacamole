import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final accountOnboardingCompleteProvider =
    AsyncNotifierProvider<AccountOnboardingCompleteNotifier, bool>(
      AccountOnboardingCompleteNotifier.new,
    );

class AccountOnboardingCompleteNotifier extends AsyncNotifier<bool> {
  static const String _keyPrefix = 'onboarding_profile_complete_v1';
  static const String _migrationOwnerKey =
      'onboarding_profile_migration_owner_v1';

  String _key(String scope) => '$_keyPrefix.$scope';

  String? get _activeScope {
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    return scope.isWritable ? scope.v2Namespace : null;
  }

  @override
  Future<bool> build() async {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    final String? account = scope.isWritable ? scope.v2Namespace : null;
    if (account == null) return false;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? stored = prefs.getBool(_key(account));
    if (stored != null) return stored;

    // Migrate the one account that owned the old device-wide completion flag.
    // Once claimed, a different account on the same device starts its own flow.
    final bool legacyComplete =
        prefs.getBool(onboardingCompleteStorageKey) ?? false;
    final String? migrationOwner = prefs.getString(_migrationOwnerKey);
    if (legacyComplete && migrationOwner == null) {
      await prefs.setString(_migrationOwnerKey, account);
      await prefs.setBool(_key(account), true);
      return true;
    }
    return false;
  }

  Future<void> complete() async {
    final String? account = _activeScope;
    if (account == null) {
      throw StateError('Account storage is not ready for onboarding.');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    await prefs.setString(_migrationOwnerKey, account);
    await prefs.setBool(_key(account), true);
    if (_activeScope == account) state = const AsyncData<bool>(true);
  }

  Future<void> reset() async {
    final String? account = _activeScope;
    if (account == null) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    await prefs.setBool(_key(account), false);
    if (_activeScope == account) state = const AsyncData<bool>(false);
  }
}
