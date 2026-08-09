import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('revalidates the Supabase session before returning it', () async {
    final _FakeAuthService service = _FakeAuthService(
      user: const User(
        id: 'user-1',
        email: 'person@example.com',
        emailVerified: true,
      ),
      session: _snapshot(),
    );
    final SupabaseAuthRemoteDataSource source =
        SupabaseAuthRemoteDataSource(authService: service);

    final session = await source.getCurrentSession();

    expect(session, isNotNull);
    expect(service.forceRefreshRequested, isTrue);
  });

  test('propagates a failed revalidation instead of returning a stale session',
      () async {
    final _FakeAuthService service = _FakeAuthService(
      user: const User(
        id: 'user-1',
        email: 'person@example.com',
        emailVerified: true,
      ),
      sessionError: FirebaseAuthException(
        code: 'user-token-expired',
        message: 'Refresh token rejected',
      ),
    );
    final SupabaseAuthRemoteDataSource source =
        SupabaseAuthRemoteDataSource(authService: service);

    await expectLater(source.getCurrentSession(), throwsA(isA<FirebaseAuthException>()));
    expect(service.forceRefreshRequested, isTrue);
  });
}

class _FakeAuthService implements AuthServiceContract {
  _FakeAuthService({this.user, this.session, this.sessionError});

  final User? user;
  final AuthSessionSnapshot? session;
  final Object? sessionError;
  bool forceRefreshRequested = false;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(user);

  @override
  Future<AuthSessionSnapshot?> getCurrentSessionSnapshot({bool forceRefresh = false}) async {
    forceRefreshRequested = forceRefresh;
    if (sessionError != null) {
      throw sessionError!;
    }
    return session;
  }

  @override
  Future<void> deleteCurrentAccount({required String password}) => throw UnimplementedError();

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) => throw UnimplementedError();

  @override
  Future<User?> reloadCurrentUser() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) => throw UnimplementedError();

  @override
  Future<void> sendPhoneOtp(String phone) => throw UnimplementedError();

  @override
  Future<UserCredential> signIn({required String email, required String password}) => throw UnimplementedError();

  @override
  Future<UserCredential> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<UserCredential> signUp({required String email, required String password}) => throw UnimplementedError();

  @override
  Future<void> updatePassword({required String newPassword}) => throw UnimplementedError();

  @override
  Future<UserCredential> verifyPhoneOtp({required String phone, required String token}) => throw UnimplementedError();
}

AuthSessionSnapshot _snapshot() {
  final DateTime now = DateTime.now();
  return AuthSessionSnapshot(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    issuedAt: now,
    expiresAt: now.add(const Duration(hours: 1)),
  );
}