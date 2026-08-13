import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boundary exposes stable signed-out and authenticated scopes', () {
    const AuthSessionBoundary signedOut = AuthSessionBoundary.initial();
    const AuthSessionBoundary userA = AuthSessionBoundary(
      generation: 1,
      userId: 'user-a',
      isTransitioning: false,
      isStorageReady: true,
    );
    const AuthSessionBoundary userB = AuthSessionBoundary(
      generation: 2,
      userId: 'user-b',
      isTransitioning: false,
      isStorageReady: true,
    );

    expect(signedOut.userId ?? 'signed_out', 'signed_out');
    expect(userA.userId ?? 'signed_out', 'user-a');
    expect(userA.userId, isNot(userB.userId));
  });
}
