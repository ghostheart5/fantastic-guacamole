import 'package:fantastic_guacamole/core/errors/result.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';

abstract class AuthServiceContract {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signIn({required String email, required String password});
  Future<UserCredential> signUp({required String email, required String password});
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithGitHub();
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword({required String newPassword});
  Future<void> sendEmailVerification();
  Future<User?> reloadCurrentUser();
  Future<String?> getIdToken({bool forceRefresh = false});
  Future<void> signOut();
  Future<void> deleteCurrentAccount({required String password});
}

extension AuthServiceContractResultX on AuthServiceContract {
  Future<AppResult<UserCredential>> signInResult({
    required String email,
    required String password,
  }) {
    return AppResult.guard<UserCredential>(
      () => signIn(email: email, password: password),
      messageFor: (Object error) => 'Sign-in failed: $error',
      errorCodeFor: _authErrorCodeFor,
    );
  }

  Future<AppResult<UserCredential>> signUpResult({
    required String email,
    required String password,
  }) {
    return AppResult.guard<UserCredential>(
      () => signUp(email: email, password: password),
      messageFor: (Object error) => 'Sign-up failed: $error',
      errorCodeFor: _authErrorCodeFor,
    );
  }

  Future<AppResult<UserCredential>> signInWithGoogleResult() {
    return AppResult.guard<UserCredential>(
      signInWithGoogle,
      messageFor: (Object error) => 'Google sign-in failed: $error',
      errorCodeFor: _authErrorCodeFor,
    );
  }

  Future<AppResult<UserCredential>> signInWithGitHubResult() {
    return AppResult.guard<UserCredential>(
      signInWithGitHub,
      messageFor: (Object error) => 'GitHub sign-in failed: $error',
      errorCodeFor: _authErrorCodeFor,
    );
  }

  Future<AppResult<void>> sendPasswordResetResult(String email) {
    return AppResult.guard<void>(
      () => sendPasswordReset(email),
      messageFor: (Object error) => 'Password reset failed: $error',
      errorCodeFor: _authErrorCodeFor,
    );
  }

  Future<AppResult<void>> deleteCurrentAccountResult({required String password}) {
    return AppResult.guard<void>(
      () => deleteCurrentAccount(password: password),
      messageFor: (Object error) => 'Account deletion failed: $error',
      errorCodeFor: _authErrorCodeFor,
    );
  }

  AppResultErrorCode _authErrorCodeFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-email':
        case 'weak-password':
        case 'missing-email':
        case 'missing-password':
          return AppResultErrorCode.validation;
        case 'too-many-requests':
          return AppResultErrorCode.timeout;
        case 'network-request-failed':
          return AppResultErrorCode.network;
        case 'no-current-user':
          return AppResultErrorCode.unauthorized;
        case 'email-already-in-use':
          return AppResultErrorCode.conflict;
        case 'operation-not-supported':
        case 'auth-unavailable':
          return AppResultErrorCode.unavailable;
      }
    }
    return AppResultErrorCode.unknown;
  }
}
