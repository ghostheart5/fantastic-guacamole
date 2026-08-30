import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';

class AlwaysAuthenticatedAuthService implements AuthServiceContract {
  AlwaysAuthenticatedAuthService({
    required this._user,
    Future<void> Function()? onSignedOut,
    Future<void> Function(String accountId)? onAccountDeleted,
  }) : _signedOutCallback = onSignedOut,
       _accountDeletedCallback = onAccountDeleted;

  final User _user;
  final Future<void> Function()? _signedOutCallback;
  final Future<void> Function(String accountId)? _accountDeletedCallback;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(_user);

  @override
  User? get currentUser => _user;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return UserCredential(user: _user);
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return UserCredential(user: _user);
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    return UserCredential(user: _user);
  }

  @override
  Future<UserCredential> signInWithGitHub() async {
    return UserCredential(user: _user);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword({required String newPassword}) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<User?> reloadCurrentUser() async {
    return _user;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return 'mock-always-auth-token';
  }

  @override
  Future<void> signOut() async {
    await _signedOutCallback?.call();
  }

  @override
  Future<AccountDeletionResult> deleteCurrentAccount({
    required String password,
  }) async {
    await _accountDeletedCallback?.call(_user.id);
    await _signedOutCallback?.call();
    return const AccountDeletionResult.completed();
  }
}
