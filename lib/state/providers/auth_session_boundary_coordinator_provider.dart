import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/account_provider_fence.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
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
      // marker in that one configuration would lock the deterministic mock
      // account out of its own fixtures on every cold start. This exception is
      // restricted to the explicitly enabled tester account and cannot apply
      // to production authentication.
      final bool isAuthorizedMockAccount =
          Env.isMockMode && Env.hasTesterFullAccess && currentId == 'mock-user';
      if (isAuthorizedMockAccount) {
        await _ref
            .read(secureStoreProvider)
            .writeString(_accountMarkerKey, currentId);
        if (!_isLatest(sequence)) return;
        invalidateAccountOwnedProviders(_ref);
        boundary.markStorageReady(generation);
        boundary.complete(generation);
        return;
      }

      if (previousId == null && storedId == null) {
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
      }

      final bool changedAccount =
          (previousId != null && previousId != currentId) ||
          (storedId != null && storedId != currentId);
      if (changedAccount) {
        // Global stores cannot safely be shown to a different account, but
        // deleting them here would lose unsynced/local-only data. Block the
        // new account until an explicit, separately confirmed data action is
        // available; the original account can sign back in and recover it.
        boundary.block(
          generation,
          issue:
              'Protected local data belongs to a different account. Sign in with the original account before switching devices or clearing local data.',
          canRecoverBySigningOut: true,
          canClearPreservedData: true,
        );
        return;
      }

      await _ref
          .read(secureStoreProvider)
          .writeString(_accountMarkerKey, currentId);
      if (!_isLatest(sequence)) return;
      invalidateAccountOwnedProviders(_ref);
      boundary.markStorageReady(generation);
      boundary.complete(generation);
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
    boundary.markStorageReady(current.generation);
    boundary.complete(current.generation);
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
          .clearForAccountSwitch(),
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
    boundary.markStorageReady(current.generation);
    boundary.complete(current.generation);
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
}) => previousUserId == null && storedUserId == null && hasUnownedData;
