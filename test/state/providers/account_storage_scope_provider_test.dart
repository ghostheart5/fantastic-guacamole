import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const User a = User(id: 'A', emailVerified: true);
  const User b = User(id: 'B', emailVerified: true);
  AuthSessionBoundary boundary(String? id, {bool transitioning = false, bool ready = true, String? issue}) => AuthSessionBoundary(generation: 1, userId: id, isTransitioning: transitioning, isStorageReady: ready, blockingIssue: issue);

  test('maps signed out to a deterministic V2 signed-out scope', () {
    final scope = resolveAccountStorageScope(user: null, boundary: boundary(null));
    expect(scope.state, AccountStorageScopeState.signedOut);
    expect(scope.v2Namespace, 'v2.signed_out');
  });

  test('maps matching ready users to distinct raw and V2 scopes', () {
    final aScope = resolveAccountStorageScope(user: a, boundary: boundary('A'));
    final bScope = resolveAccountStorageScope(user: b, boundary: boundary('B'));
    expect(aScope.isWritable, isTrue);
    expect(aScope.rawUserId, 'A');
    expect(aScope.v2Namespace, isNot(bScope.v2Namespace));
    expect(aScope.legacyV1Candidate, 'A');
  });

  test('does not expose signed-out or writable scope during unsafe states', () {
    for (final AuthSessionBoundary state in <AuthSessionBoundary>[
      boundary('B', transitioning: true),
      boundary('A', ready: false),
      boundary('A', issue: 'blocked'),
      boundary('B'),
    ]) {
      final scope = resolveAccountStorageScope(user: a, boundary: state);
      expect(scope.state, AccountStorageScopeState.unsafe);
      expect(scope.isWritable, isFalse);
      expect(scope.v2Namespace, isNull);
    }
  });
}
