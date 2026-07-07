import 'package:fantastic_guacamole/core/errors/result.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';

abstract class AuthServiceContract {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signIn({required String email, required String password});
  Future<UserCredential> signUp({required String email, required String password});
  Future<UserCredential> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
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
    );
  }

  Future<AppResult<UserCredential>> signUpResult({
    required String email,
    required String password,
  }) {
    return AppResult.guard<UserCredential>(
      () => signUp(email: email, password: password),
      messageFor: (Object error) => 'Sign-up failed: $error',
    );
  }

  Future<AppResult<UserCredential>> signInWithGoogleResult() {
    return AppResult.guard<UserCredential>(
      signInWithGoogle,
      messageFor: (Object error) => 'Google sign-in failed: $error',
    );
  }

  Future<AppResult<void>> sendPasswordResetResult(String email) {
    return AppResult.guard<void>(
      () => sendPasswordReset(email),
      messageFor: (Object error) => 'Password reset failed: $error',
    );
  }

  Future<AppResult<void>> deleteCurrentAccountResult({required String password}) {
    return AppResult.guard<void>(
      () => deleteCurrentAccount(password: password),
      messageFor: (Object error) => 'Account deletion failed: $error',
    );
  }
}
