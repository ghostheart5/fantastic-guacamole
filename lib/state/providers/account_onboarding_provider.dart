import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _AccountRecords = ({bool any, bool hasCompletedTasks});

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
    if (legacyOwnership == LegacyScopeOwnership.provenOwned &&
        (prefs.getBool(onboardingCompleteStorageKey) ?? false)) {
      return true;
    }
    // This install has no setup answer for the now-ready account. Its records
    // are checked afterwards, so the answer never waits on the record stores.
    final AccountOperation owner = AccountOperation.capture(ref);
    unawaited(_adoptAfterBuild(owner, account));
    return false;
  }

  Future<void> _adoptAfterBuild(AccountOperation owner, String account) async {
    try {
      await Future<void>.value();
      // This build's own result must settle first so it cannot replace ours.
      final bool complete = await future;
      if (owner.isCurrent) {
        await _adoptReturningAccount(owner, account, complete);
      }
    } on Object catch (error, stackTrace) {
      // Nothing was decided; the next account-ready read or restore retries.
      Logger.errorCategory(
        'onboarding',
        'Returning account setup state was not inferred',
        error,
        stackTrace,
      );
    }
  }

  /// After a cloud restore wrote the account's records to this device. Setup
  /// ends if this install has no setup answer for the account, and the
  /// first-run guide ends unless the person skipped, paused or restarted it.
  Future<void> adoptRestoredRecords() async {
    final String? account = _activeScope;
    if (account == null) return;
    final AccountOperation owner = AccountOperation.capture(ref);
    final bool complete = await future;
    if (owner.isCurrent) await _adoptReturningAccount(owner, account, complete);
  }

  /// If [account]'s own tasks, habits or goals are on this device, it is a
  /// returning account: setup and the first-run guide count as done, each
  /// recorded once. A new account with no records still gets setup, and
  /// nothing is recorded, so a restore that fills its stores later can still
  /// decide. A restart of setup the person asked for is never overridden.
  Future<void> _adoptReturningAccount(
    AccountOperation owner,
    String account,
    bool complete,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? answer = prefs.getBool(_key(account));
    if (!owner.isCurrent || answer == false) return;
    final _AccountRecords? records = await _readRecords();
    if (!owner.isCurrent || records == null || !records.any) return;
    await ref
        .read(adaptiveGuidanceProvider.notifier)
        .adoptReturningAccount(
          account: account,
          hasCompletedTasks: records.hasCompletedTasks,
          // Once setup was done on this install, the person may have moved
          // the guide on by their own actions; that progress is kept.
          keepProgressMadeHere: answer == true || complete,
          shouldContinue: () => owner.isCurrent,
        );
    // Setup is recorded after the guide, so an interrupted write is retried.
    // Checked and written with no wait between, so an explicit completion or
    // reset written meanwhile is kept.
    if (!owner.isCurrent || complete || prefs.getBool(_key(account)) != null) {
      return;
    }
    await prefs.setBool(_key(account), true);
    if (owner.isCurrent) state = const AsyncData<bool>(true);
  }

  /// The active account's own tasks, habits and goals on this device. Null
  /// when they cannot be read, which never counts as a returning account.
  Future<_AccountRecords?> _readRecords() async {
    try {
      final List<TaskEntity> tasks = await ref
          .read(domainTaskRepositoryProvider)
          .getAllTasks();
      final bool any =
          tasks.isNotEmpty ||
          ref.read(domainGoalRepositoryProvider).getGoals().isNotEmpty ||
          (await ref.read(domainHabitRepositoryProvider).getHabits())
              .isNotEmpty;
      return (
        any: any,
        hasCompletedTasks: tasks.any((TaskEntity task) => task.isCompleted),
      );
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'onboarding',
        'Account records could not be read for setup',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> complete() async {
    final String? account = _activeScope;
    if (account == null) {
      throw StateError('Account storage is not ready for onboarding.');
    }
    // A pending initial read must settle before the explicit completion write.
    // Otherwise its stale false result can replace the successful state below.
    await future;
    if (_activeScope != account) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    await prefs.setBool(_key(account), true);
    if (_activeScope == account) state = const AsyncData<bool>(true);
  }

  Future<void> reset() async {
    final String? account = _activeScope;
    if (account == null) return;
    // The same ordering keeps a late true read from undoing an explicit reset.
    await future;
    if (_activeScope != account) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_activeScope != account) return;
    await prefs.setBool(_key(account), false);
    if (_activeScope == account) state = const AsyncData<bool>(false);
  }
}
