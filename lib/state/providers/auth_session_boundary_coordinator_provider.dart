import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/account_provider_fence.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _accountMarkerKey = 'auth_boundary_account_marker_v1';

final authSessionBoundaryCoordinatorProvider =
    Provider<AuthSessionBoundaryCoordinator>((Ref ref) {
      final AuthSessionBoundaryCoordinator coordinator =
          AuthSessionBoundaryCoordinator(ref);
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

/// Serializes every authentication transition before account-owned providers
/// are allowed to hydrate. A sequence fence prevents an obsolete transition
/// from clearing data, writing an owner marker, or opening the storage gate
/// after a newer authentication event has arrived.
class AuthSessionBoundaryCoordinator {
  AuthSessionBoundaryCoordinator(this._ref);

  final Ref _ref;
  final Completer<void> _initialTransition = Completer<void>();
  ProviderSubscription<AsyncValue<User?>>? _subscription;
  Future<void> _transitionTail = Future<void>.value();
  int _latestSequence = 0;
  bool _started = false;
  bool _disposed = false;

  Future<void> initialize() {
    if (_started) return _initialTransition.future;
    _started = true;
    _subscription = _ref.listen<AsyncValue<User?>>(
      authUserProvider,
      _onAuthState,
      fireImmediately: true,
    );
    return _initialTransition.future;
  }

  void _onAuthState(AsyncValue<User?>? previous, AsyncValue<User?> next) {
    if (_disposed || next.isLoading) return;
    final int sequence = ++_latestSequence;
    final User? previousUser = previous?.asData?.value;
    final User? currentUser = next.asData?.value;
    final Object? authError = next.hasError ? next.error : null;

    _transitionTail = _transitionTail
        .then((_) async {
          if (!_isLatest(sequence)) return;
          if (authError != null) {
            _blockForAuthError(sequence, previousUser);
            return;
          }
          await _synchronizeBoundary(
            sequence: sequence,
            previousUser: previousUser,
            currentUser: currentUser,
          );
        })
        .onError((Object error, StackTrace stackTrace) {
          _blockForUnexpectedError(sequence, error, stackTrace);
        })
        .whenComplete(() {
          if (_isLatest(sequence) && !_initialTransition.isCompleted) {
            _initialTransition.complete();
          }
        });
  }

  Future<void> _synchronizeBoundary({
    required int sequence,
    required User? previousUser,
    required User? currentUser,
  }) async {
    final String? currentId = _validId(currentUser?.id);
    final AuthSessionBoundaryNotifier boundary = _ref.read(
      authSessionBoundaryProvider.notifier,
    );
    final AuthSessionBoundary existing = _ref.read(authSessionBoundaryProvider);
    if (currentId != null &&
        existing.userId == currentId &&
        existing.isStorageReady &&
        !existing.isTransitioning &&
        existing.blockingIssue == null) {
      return;
    }

    final occurrenceCoordinator = _ref.read(taskOccurrenceCoordinatorProvider);
    final outcomeRepository = _ref.read(decisionOutcomeRepositoryProvider);
    final int generation = boundary.begin(
      userId: currentId,
      isTransitioning: true,
    );
    await occurrenceCoordinator.cancelAndDrain();
    await outcomeRepository?.drain();
    if (!_isLatest(sequence)) return;
    invalidateAccountOwnedProviders(_ref);

    try {
      final String? previousId = _validId(previousUser?.id);
      final String? storedId = _validId(
        await _ref.read(secureStoreProvider).readString(_accountMarkerKey),
      );
      if (!_isLatest(sequence)) return;

      if (currentId == null) {
        // Signing out must not destroy local or queued work. Retaining the
        // owner marker lets a later sign-in prove which account may reopen it.
        invalidateAccountOwnedProviders(_ref);
        boundary.complete(generation, storageReady: false);
        return;
      }

      // QA mock mode uses an in-memory secure store, while its Hive fixtures
      // intentionally survive app restarts. Requiring a persisted secure owner
      // marker in that one configuration would lock the deterministic primary
      // mock account out of its own fixtures on every cold start. It may claim
      // only a missing marker; it can never overwrite another proven owner.
      final bool isAuthorizedMockAccount =
          Env.isMockMode && Env.hasTesterFullAccess && currentId == 'mock-user';
      if (isAuthorizedMockAccount && storedId == null) {
        await _ref
            .read(secureStoreProvider)
            .writeString(_accountMarkerKey, currentId);
        if (!_isLatest(sequence)) return;
        invalidateAccountOwnedProviders(_ref);
        await _openStorageGate(
          boundary,
          generation,
          accountId: currentId,
          sequence: sequence,
          legacyOwnership: LegacyScopeOwnership.provenOwned,
        );
        return;
      }

      if (storedId == null) {
        final bool hasUnownedData = await _ref
            .read(localUserDataCleanupServiceProvider)
            .hasUnownedAccountData();
        if (!_isLatest(sequence)) return;
        if (shouldBlockForUnownedData(
          previousUserId: previousId,
          storedUserId: storedId,
          hasUnownedData: hasUnownedData,
        )) {
          boundary.block(
            generation,
            issue:
                'Preserved device data was found, but its account owner cannot be verified. Review it before ChronoSpark unlocks account data.',
            canRecoverBySigningOut: true,
            canClaimPreservedData: true,
            canClearPreservedData: true,
          );
          return;
        }
        await _ref
            .read(secureStoreProvider)
            .writeString(_accountMarkerKey, currentId);
        if (!_isLatest(sequence)) return;
        invalidateAccountOwnedProviders(_ref);
        await _openStorageGate(
          boundary,
          generation,
          accountId: currentId,
          sequence: sequence,
          legacyOwnership: LegacyScopeOwnership.provenOwned,
        );
        return;
      }

      // All active account-owned stores are V2 namespaced. A different account
      // can therefore open its own namespace without clearing or relabelling
      // the original owner's preserved legacy data.
      final LegacyScopeOwnership legacyOwnership = storedId == currentId
          ? LegacyScopeOwnership.provenOwned
          : LegacyScopeOwnership.provenNotOwned;
      invalidateAccountOwnedProviders(_ref);
      await _openStorageGate(
        boundary,
        generation,
        accountId: currentId,
        sequence: sequence,
        legacyOwnership: legacyOwnership,
      );
    } on Object catch (error, stackTrace) {
      if (!_isLatest(sequence)) return;
      Logger.errorCategory(
        'AuthBoundary',
        'Account storage isolation failed.',
        error,
        stackTrace,
      );
      boundary.block(
        generation,
        issue: 'ChronoSpark could not isolate account data safely.',
        canRecoverBySigningOut: true,
      );
    }
  }

  /// Explicitly assigns markerless preserved data to the currently signed-in
  /// account. This is the only path that can adopt ownership-ambiguous data.
  Future<void> claimPreservedDataForCurrentAccount() async {
    final User? user = _ref.read(authUserProvider).asData?.value;
    final String? userId = _validId(user?.id);
    final AuthSessionBoundary current = _ref.read(authSessionBoundaryProvider);
    if (userId == null ||
        current.userId != userId ||
        !current.canClaimPreservedData ||
        current.isTransitioning) {
      return;
    }
    final int sequence = _latestSequence;
    await _ref.read(secureStoreProvider).writeString(_accountMarkerKey, userId);
    if (!_isLatest(sequence) ||
        _validId(_ref.read(authUserProvider).asData?.value?.id) != userId) {
      return;
    }
    invalidateAccountOwnedProviders(_ref);
    final AuthSessionBoundaryNotifier boundary = _ref.read(
      authSessionBoundaryProvider.notifier,
    );
    await _openStorageGate(
      boundary,
      current.generation,
      accountId: userId,
      sequence: sequence,
      legacyOwnership: LegacyScopeOwnership.provenOwned,
    );
  }

  /// Clears preserved account-owned local data only after an explicit user
  /// confirmation from the lock UI. This is intentionally separate from
  /// sign-out/account-change cleanup so a transition can never delete data by
  /// itself.
  Future<void> clearPreservedDataForCurrentAccount() async {
    final User? user = _ref.read(authUserProvider).asData?.value;
    final String? userId = _validId(user?.id);
    final AuthSessionBoundary current = _ref.read(authSessionBoundaryProvider);
    if (userId == null ||
        current.userId != userId ||
        !current.canClearPreservedData ||
        current.isTransitioning) {
      return;
    }
    final int sequence = _latestSequence;
    await runAccountStorageMutation(
      () => _ref
          .read(localUserDataCleanupServiceProvider)
          .clearUnownedLegacyData(),
    );
    if (!_isLatest(sequence) ||
        _validId(_ref.read(authUserProvider).asData?.value?.id) != userId) {
      return;
    }
    await _ref.read(secureStoreProvider).writeString(_accountMarkerKey, userId);
    invalidateAccountOwnedProviders(_ref);
    final AuthSessionBoundaryNotifier boundary = _ref.read(
      authSessionBoundaryProvider.notifier,
    );
    await _openStorageGate(
      boundary,
      current.generation,
      accountId: userId,
      sequence: sequence,
      legacyOwnership: LegacyScopeOwnership.provenOwned,
    );
  }

  /// Runs the destructive "Clear this device" action behind the same account
  /// lifecycle fence as authentication transitions. The supplied identity is
  /// mandatory and must still be the current authenticated account.
  Future<void> clearLocalDataForCurrentAccount(String expectedAccountId) {
    final String? normalizedAccountId = _validId(expectedAccountId);
    if (normalizedAccountId == null) {
      return Future<void>.error(
        ArgumentError.value(
          expectedAccountId,
          'expectedAccountId',
          'Must be non-empty and trimmed.',
        ),
      );
    }
    if (!_started || _disposed) {
      return Future<void>.error(
        StateError('The account lifecycle coordinator is unavailable.'),
      );
    }

    final int sequence = ++_latestSequence;
    final Future<void> operation = _transitionTail.then(
      (_) => _clearLocalDataForCurrentAccount(
        sequence: sequence,
        expectedAccountId: normalizedAccountId,
      ),
    );
    _transitionTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Logger.errorCategory(
          'AuthBoundary',
          'Explicit local account-data clearing failed.',
          error,
          stackTrace,
        );
      },
    );
    return operation;
  }

  Future<void> _clearLocalDataForCurrentAccount({
    required int sequence,
    required String expectedAccountId,
  }) async {
    if (!_isLatest(sequence)) {
      throw StateError('The authenticated account changed before clearing.');
    }
    final String? currentAccountId = _validId(
      _ref.read(authUserProvider).asData?.value?.id,
    );
    final AuthSessionBoundary current = _ref.read(authSessionBoundaryProvider);
    if (currentAccountId != expectedAccountId ||
        current.userId != expectedAccountId ||
        current.isTransitioning ||
        !current.isStorageReady ||
        current.blockingIssue != null) {
      throw StateError(
        'Local data can only be cleared for the current unlocked account.',
      );
    }

    final AuthSessionBoundaryNotifier boundary = _ref.read(
      authSessionBoundaryProvider.notifier,
    );
    final int generation = boundary.begin(
      userId: expectedAccountId,
      isTransitioning: true,
    );
    try {
      await _ref.read(taskOccurrenceCoordinatorProvider).cancelAndDrain();
      await _ref.read(decisionOutcomeRepositoryProvider)?.drain();
      if (!_isLatestAccount(sequence, expectedAccountId, generation)) return;

      invalidateAccountOwnedProviders(_ref);
      final String? storedAccountId = _validId(
        await _ref
            .read(secureStoreProvider)
            .readString(AccountDataRegistry.accountBoundaryOwnerKey),
      );
      await _ref
          .read(localUserDataCleanupServiceProvider)
          .clearForAccountSwitch(expectedAccountId);
      if (!_isLatestAccount(sequence, expectedAccountId, generation)) return;

      invalidateAccountOwnedProviders(_ref);
      final LegacyScopeOwnership legacyOwnership =
          storedAccountId == expectedAccountId
          ? LegacyScopeOwnership.provenOwned
          : LegacyScopeOwnership.provenNotOwned;
      if (legacyOwnership == LegacyScopeOwnership.provenOwned) {
        await _ref
            .read(secureStoreProvider)
            .writeString(
              AccountDataRegistry.accountBoundaryOwnerKey,
              expectedAccountId,
            );
      }
      await _openStorageGate(
        boundary,
        generation,
        accountId: expectedAccountId,
        sequence: sequence,
        legacyOwnership: legacyOwnership,
      );
    } on Object {
      if (_isLatestAccount(sequence, expectedAccountId, generation)) {
        invalidateAccountOwnedProviders(_ref);
        boundary.block(
          generation,
          issue: 'ChronoSpark could not clear local account data safely.',
          canRecoverBySigningOut: true,
        );
      }
      rethrow;
    }
  }

  Future<void> _openStorageGate(
    AuthSessionBoundaryNotifier boundary,
    int generation, {
    required String accountId,
    required int sequence,
    required LegacyScopeOwnership legacyOwnership,
  }) async {
    if (legacyOwnership == LegacyScopeOwnership.provenOwned) {
      await AccountScopedSharedPrefsStore(
        delegate: _ref.read(sharedPrefsStoreProvider),
        scope: AccountStorageScope.authenticated(accountId),
        legacyOwnership: legacyOwnership,
      ).migrateOwnedLegacyValues(AccountDataRegistry.reminderPreferenceKeys);
    }
    if (!_isLatestAccount(sequence, accountId, generation)) return;
    boundary.markStorageReady(generation, legacyOwnership: legacyOwnership);
    boundary.complete(generation);
    _ref.read(getTasksUseCaseProvider);
  }

  bool _isLatestAccount(int sequence, String accountId, int generation) {
    if (!_isLatest(sequence)) return false;
    if (_validId(_ref.read(authUserProvider).asData?.value?.id) != accountId) {
      return false;
    }
    return _ref.read(authSessionBoundaryProvider).generation == generation;
  }

  void _blockForAuthError(int sequence, User? previousUser) {
    if (!_isLatest(sequence)) return;
    final AuthSessionBoundaryNotifier boundary = _ref.read(
      authSessionBoundaryProvider.notifier,
    );
    final int generation = boundary.begin(
      userId: _validId(previousUser?.id),
      isTransitioning: true,
    );
    invalidateAccountOwnedProviders(_ref);
    boundary.block(
      generation,
      issue: 'Authentication state could not be verified safely.',
      canRecoverBySigningOut: true,
      canClearPreservedData: false,
    );
  }

  void _blockForUnexpectedError(
    int sequence,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!_isLatest(sequence)) return;
    Logger.errorCategory(
      'AuthBoundary',
      'Serialized authentication transition failed.',
      error,
      stackTrace,
    );
    final AuthSessionBoundaryNotifier boundary = _ref.read(
      authSessionBoundaryProvider.notifier,
    );
    final int generation = boundary.begin(userId: null, isTransitioning: true);
    invalidateAccountOwnedProviders(_ref);
    boundary.block(
      generation,
      issue: 'ChronoSpark could not isolate account data safely.',
      canRecoverBySigningOut: true,
      canClearPreservedData: false,
    );
  }

  bool _isLatest(int sequence) => !_disposed && sequence == _latestSequence;

  void dispose() {
    _disposed = true;
    _subscription?.close();
    if (!_initialTransition.isCompleted) {
      _initialTransition.complete();
    }
  }
}

String? _validId(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || normalized != value) return null;
  return normalized;
}

bool shouldBlockForUnownedData({
  required String? previousUserId,
  required String? storedUserId,
  required bool hasUnownedData,
}) {
  // A transient in-memory auth value cannot prove ownership of durable legacy
  // data. Only the stable secure marker (or the explicit claim flow) can.
  return storedUserId == null && hasUnownedData;
}
