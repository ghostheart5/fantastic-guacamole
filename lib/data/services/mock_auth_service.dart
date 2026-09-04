import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';

class MockAuthService implements AuthServiceContract {
  MockAuthService({
    Future<void> Function(String accountId)? onBeforeSignedOut,
    Future<void> Function()? onSignedOut,
    Future<void> Function(String accountId)? onAccountDeleted,
  }) : _beforeSignedOutCallback = onBeforeSignedOut,
       _signedOutCallback = onSignedOut,
       _accountDeletedCallback = onAccountDeleted;

  final Future<void> Function(String accountId)? _beforeSignedOutCallback;
  final Future<void> Function()? _signedOutCallback;
  final Future<void> Function(String accountId)? _accountDeletedCallback;

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
  Future<void> signOut() async {
    final String? accountId = _currentUser?.id;
    if (accountId != null) {
      await _beforeSignedOutCallback?.call(accountId);
    }
    _currentUser = null;
    await _signedOutCallback?.call();
  }

  @override
  Future<AccountDeletionResult> deleteCurrentAccount({
    required String password,
  }) async {
    final String? accountId = _currentUser?.id;
    if (accountId == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user found.',
      );
    }
    await _beforeSignedOutCallback?.call(accountId);
    _currentUser = null;
    await _accountDeletedCallback?.call(accountId);
    await _signedOutCallback?.call();
    return const AccountDeletionResult.completed();
  }

  @override
  Future<PendingAccountDeletionStatus?> readPendingAccountDeletion() async =>
      null;

  @override
  Future<AccountDeletionResult?> refreshPendingAccountDeletion() async => null;

  @override
  Future<void> forgetPendingAccountDeletion() async {}
}
