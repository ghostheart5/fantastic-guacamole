import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_coordinator_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const User user = User(
    id: 'account-a',
    email: 'a@example.test',
    emailVerified: true,
  );

  test('storage opens only for a ready matching account boundary', () {
    final AccountStorageScope ready = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final AccountStorageScope transitioning = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: true,
        isStorageReady: true,
      ),
    );
    final AccountStorageScope mismatched = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    final AccountStorageScope blocked = resolveAccountStorageScope(
      user: user,
      boundary: const AuthSessionBoundary(
        generation: 3,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
        blockingIssue: 'ownership unknown',
      ),
    );

    expect(ready.isWritable, isTrue);
    expect(ready.rawUserId, 'account-a');
    expect(transitioning.state, AccountStorageScopeState.unsafe);
    expect(mismatched.state, AccountStorageScopeState.unsafe);
    expect(blocked.state, AccountStorageScopeState.unsafe);
    expect(
      resolveAccountStorageScope(
        user: null,
        boundary: const AuthSessionBoundary.initial(),
      ).state,
      AccountStorageScopeState.signedOut,
    );
  });

  test('markerless data is never silently assigned to a signed-in user', () {
    expect(
      shouldBlockForUnownedData(
        previousUserId: null,
        storedUserId: null,
        hasUnownedData: true,
      ),
      isTrue,
    );
    expect(
      shouldBlockForUnownedData(
        previousUserId: null,
        storedUserId: null,
        hasUnownedData: false,
      ),
      isFalse,
    );
    expect(
      shouldBlockForUnownedData(
        previousUserId: 'account-a',
        storedUserId: null,
        hasUnownedData: true,
      ),
      isFalse,
    );
    expect(
      shouldBlockForUnownedData(
        previousUserId: null,
        storedUserId: 'account-a',
        hasUnownedData: true,
      ),
      isFalse,
    );
  });

  test('stale generations cannot reopen or overwrite the boundary', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AuthSessionBoundaryNotifier notifier = container.read(
      authSessionBoundaryProvider.notifier,
    );

    final int accountA = notifier.begin(
      userId: 'account-a',
      isTransitioning: true,
    );
    final int accountB = notifier.begin(
      userId: 'account-b',
      isTransitioning: true,
    );
    notifier.markStorageReady(accountA);
    notifier.complete(accountA);

    expect(container.read(authSessionBoundaryProvider).userId, 'account-b');
    expect(container.read(authSessionBoundaryProvider).isStorageReady, isFalse);

    notifier.markStorageReady(accountB);
    notifier.complete(accountB);
    final AuthSessionBoundary ready = container.read(
      authSessionBoundaryProvider,
    );
    expect(ready.userId, 'account-b');
    expect(ready.isStorageReady, isTrue);
    expect(ready.isTransitioning, isFalse);
  });

  test('ownership block exposes claim, not destructive discard', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AuthSessionBoundaryNotifier notifier = container.read(
      authSessionBoundaryProvider.notifier,
    );
    final int generation = notifier.begin(
      userId: 'account-a',
      isTransitioning: true,
    );

    notifier.block(
      generation,
      issue: 'ownership unknown',
      canRecoverBySigningOut: true,
      canClaimPreservedData: true,
    );

    final AuthSessionBoundary blocked = container.read(
      authSessionBoundaryProvider,
    );
    expect(blocked.isStorageReady, isFalse);
    expect(blocked.blockingIssue, 'ownership unknown');
    expect(blocked.canClaimPreservedData, isTrue);
    expect(blocked.canRecoverBySigningOut, isTrue);
  });
}
