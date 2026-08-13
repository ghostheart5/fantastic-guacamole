import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source() {
  return File(
    'lib/state/providers/auth_session_lifecycle_provider.dart',
  ).readAsStringSync();
}

int _position(String source, String needle) {
  final int position = source.indexOf(needle);
  expect(position, isNonNegative, reason: 'Missing lifecycle step: $needle');
  return position;
}

void main() {
  test('uses the committed boundary authority without local duplicates', () {
    final String source = _source();

    expect(
      source,
      contains("import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';"),
    );
    expect(source, isNot(contains('class AuthSessionBoundary {')));
    expect(source, isNot(contains('class AuthSessionBoundaryNotifier')));
    expect(
      source,
      isNot(contains('final authSessionBoundaryProvider =')),
    );
  });

  test('serializes transitions and keeps the required success ordering', () {
    final String source = _source();
    final String transition = source.substring(
      _position(source, 'Future<int> _transitionSerial('),
      _position(source, 'Future<int> _recoverMismatchedAuthenticatedSessionSerial()'),
    );

    expect(source, contains('Future<void> _transitionTail = Future<void>.value();'));
    expect(
      _position(transition, 'FirebaseSupabaseBridgeRepository.suspendSessionWrites();'),
      lessThan(_position(transition, 'await _cancelAndDrainIdentityOwnedWork(')),
    );
    expect(
      _position(transition, 'await _cancelAndDrainIdentityOwnedWork('),
      lessThan(_position(transition, '_invalidateIdentityOwnedState();')),
    );
    expect(
      _position(transition, '_invalidateIdentityOwnedState();'),
      lessThan(_position(transition, '_setIdentity(null);')),
    );
    expect(
      _position(transition, '_setIdentity(null);'),
      lessThan(_position(transition, 'final _SessionOwnershipStore ownershipStore')),
    );
    expect(
      _position(transition, 'await ownershipStore.migrateTrustedLegacyUserData(nextUserId);'),
      lessThan(transition.lastIndexOf('_setIdentity(user);')),
    );
    expect(
      _position(transition, '_setIdentity(user);'),
      lessThan(_position(transition, '.complete(generation, storageReady: nextUserId != null);')),
    );
    expect(
      _position(transition, '.complete(generation, storageReady: nextUserId != null);'),
      lessThan(_position(transition, 'FirebaseSupabaseBridgeRepository.resumeSessionWrites();')),
    );
  });

  test('drains every committed Root-05 owner before invalidation', () {
    final String source = _source();
    final int drain = _position(source, 'Future<void> _cancelAndDrainIdentityOwnedWork(');
    final int invalidation = _position(source, 'void _invalidateIdentityOwnedState()');

    for (final String operation in <String>[
      'taskRepository.cancelAndDrain()',
      'goalRepository.cancelAndDrain()',
      'habitRepository.cancelAndDrain()',
      'settingsRepository.cancelAndDrain()',
      'syncMutationDispatcher.cancelAndDrain()',
      'recovery.cancelAndDrain()',
      'syncActions.cancelAndDrain()',
      'cancelAndDrainExtendedDomainSessionState(_ref)',
      'profile.cancelAndDrainWrites()',
      'learning.cancelAndDrainWrites()',
      '.drainMutations()',
      '.cancelAndDrain(),',
    ]) {
      final int operationPosition = _position(source, operation);
      expect(operationPosition, greaterThan(drain));
      expect(operationPosition, lessThan(invalidation));
    }
  });

  test('invalidation is derived/session-only and precedes identity synchronization', () {
    final String source = _source();
    final int invalidation = _position(source, 'void _invalidateIdentityOwnedState()');
    final String invalidationBody = source.substring(
      invalidation,
      source.indexOf('\n}\n\nString? _normalizedUserId', invalidation),
    );

    expect(_position(source, 'invalidateInsightsSessionState(_ref);'), greaterThan(invalidation));
    expect(_position(source, 'invalidateMonetizationSessionState(_ref);'), greaterThan(invalidation));
    final String transition = source.substring(
      _position(source, 'Future<int> _transitionSerial('),
      _position(source, 'Future<int> _recoverMismatchedAuthenticatedSessionSerial()'),
    );
    expect(
      _position(transition, '_invalidateIdentityOwnedState();'),
      lessThan(_position(transition, '_setIdentity(null);')),
    );
    expect(invalidationBody, isNot(contains('_authTransitionCleanupProvider')));
  });

  test('failed transitions block the boundary and do not resume writes', () {
    final String source = _source();
    final int catchBlock = _position(source, "'Authentication transition isolation failed.'");
    final int block = source.indexOf('.block(generation);', catchBlock);
    expect(block, isNonNegative);

    final int resume = _position(
      source,
      'FirebaseSupabaseBridgeRepository.resumeSessionWrites();',
    );
    expect(
      source.substring(catchBlock),
      isNot(contains('FirebaseSupabaseBridgeRepository.resumeSessionWrites();')),
    );
    expect(resume, lessThan(catchBlock));
  });
}
