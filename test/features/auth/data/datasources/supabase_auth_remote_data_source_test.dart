import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the real session snapshot metadata instead of fabricating values', () async {
    final DateTime issuedAt = DateTime.utc(2026, 7, 17, 12);
    final DateTime expiresAt = DateTime.utc(2026, 7, 17, 13);
    final _FakeAuthService service = _FakeAuthService(
      user: const User(
        id: 'user-1',
        email: 'pilot@chronospark.app',
        displayName: 'Pilot',
        emailVerified: true,
      ),
      snapshot: AuthSessionSnapshot(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        expiresAt: expiresAt,
        issuedAt: issuedAt,
      ),
    );

    final SupabaseAuthRemoteDataSource source =
        SupabaseAuthRemoteDataSource(authService: service);

    final session = await source.getCurrentSession();

    expect(session, isNotNull);
    expect(session!.accessToken, 'access-token');
    expect(session.refreshToken, 'refresh-token');
    expect(session.issuedAt, issuedAt);
    expect(session.expiresAt, expiresAt);
  });

  test('returns null when the auth service has no current session snapshot', () async {
    final _FakeAuthService service = _FakeAuthService(
      user: const User(
        id: 'user-1',
        email: 'pilot@chronospark.app',
        displayName: 'Pilot',
        emailVerified: true,
      ),
      snapshot: null,
    );

    final SupabaseAuthRemoteDataSource source =
        SupabaseAuthRemoteDataSource(authService: service);

    expect(await source.getCurrentSession(), isNull);
  });
}

class _FakeAuthService implements AuthServiceContract {
  _FakeAuthService({required User? user, required AuthSessionSnapshot? snapshot})
    : this._(user, snapshot);

  _FakeAuthService._(this._user, this._snapshot);

  final User? _user;
  final AuthSessionSnapshot? _snapshot;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(_user);

  @override
  User? get currentUser => _user;

  @override
  Future<void> deleteCurrentAccount({required String password}) async {}

  @override
  Future<AuthSessionSnapshot?> getCurrentSessionSnapshot({
    bool forceRefresh = false,
  }) async {
    return _snapshot;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return _snapshot?.accessToken;
  }

  @override
  Future<User?> reloadCurrentUser() async => _user;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async => UserCredential(user: _user);

  @override
  Future<UserCredential> signInWithGitHub() async => UserCredential(user: _user);

  @override
  Future<UserCredential> signInWithGoogle() async => UserCredential(user: _user);

  @override
  Future<void> signOut() async {}

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async => UserCredential(user: _user);

  @override
  Future<void> updatePassword({required String newPassword}) async {}
}