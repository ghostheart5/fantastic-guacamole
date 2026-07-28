import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';

class MockAuthService implements AuthServiceContract {
  MockAuthService();

  User? _currentUser;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(_currentUser);

  @override
  User? get currentUser => _currentUser;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    _currentUser = User(
      id: 'mock-user',
      email: email,
      displayName: 'Tester',
      emailVerified: true,
    );
    return UserCredential(user: _currentUser);
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    _currentUser = User(
      id: 'mock-user',
      email: email,
      displayName: 'Tester',
      emailVerified: true,
    );
    return UserCredential(user: _currentUser);
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    _currentUser = const User(
      id: 'mock-google-user',
      email: 'mock@chronospark.app',
      displayName: 'Tester',
      emailVerified: true,
    );
    return UserCredential(user: _currentUser);
  }

  @override
  Future<UserCredential> signInWithGitHub() async {
    _currentUser = const User(
      id: 'mock-github-user',
      email: 'mock@chronospark.app',
      displayName: 'Tester',
      emailVerified: true,
    );
    return UserCredential(user: _currentUser);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<User?> reloadCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return 'mock-token';
  }

  @override
  Future<AuthSessionSnapshot?> getCurrentSessionSnapshot({
    bool forceRefresh = false,
  }) async {
    if (_currentUser == null) {
      return null;
    }
    final DateTime issuedAt = DateTime.now();
    return AuthSessionSnapshot(
      accessToken: 'mock-token',
      refreshToken: 'mock-refresh-token',
      expiresAt: issuedAt.add(const Duration(hours: 1)),
      issuedAt: issuedAt,
    );
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    _currentUser = null;
  }
}
