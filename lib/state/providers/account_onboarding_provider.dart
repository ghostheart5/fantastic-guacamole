import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
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
  SharedPreferences? _preferences;

  String _key(String scope) => '$_keyPrefix.$scope';

  String? get _activeScope {
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    return scope.isWritable ? scope.v2Namespace : null;
  }

  @override
  FutureOr<bool> build() {
    // A token refresh may emit a new scope object for the same account. Avoid
    // reloading its completed flag: a transient loading state would send an
    // already-onboarded user back through the route guard. Account changes and
    // unsafe storage still invalidate immediately through the selected key.
    final String? account = ref.watch(
      accountStorageScopeProvider.select(
        (scope) => scope.isWritable ? scope.v2Namespace : null,
      ),
    );
    final LegacyScopeOwnership legacyOwnership = ref.watch(
      accountLegacyOwnershipProvider,
    );
    if (account == null) return false;

    final SharedPreferences? prefs = _preferences;
    if (prefs != null) return _readCompletion(prefs, account, legacyOwnership);
    return _loadCompletion(account, legacyOwnership);
  }

  Future<bool> _loadCompletion(
    String account,
    LegacyScopeOwnership legacyOwnership,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _preferences = prefs;
    return _readCompletion(prefs, account, legacyOwnership);
  }

  bool _readCompletion(
    SharedPreferences prefs,
    String account,
    LegacyScopeOwnership legacyOwnership,
  ) {
    // Re-read the current account's key synchronously once preferences are
    // initialized. Ownership refresh and return sign-in must not manufacture
    // an incomplete-setup interval. No completion value is shared across keys.
    final bool? stored = prefs.getBool(_key(account));
    if (stored != null) return stored;

    // Legacy completion remains device-global and read-only. Only the account
    // proven by the authentication boundary may use it as a fallback.
    return legacyOwnership == LegacyScopeOwnership.provenOwned &&
        (prefs.getBool(onboardingCompleteStorageKey) ?? false);
  }

  Future<void> complete() async {
    final String? account = _activeScope;
    if (account == null) {
      throw StateError('Account storage is not ready for onboarding.');
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
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
