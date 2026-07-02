import 'package:fantastic_guacamole/data/models/auth_models.dart';

abstract class AuthServiceContract {
  Stream<User?> authStateChanges();
  User? get currentUser;
  Future<UserCredential> signIn({
    required String email,
    required String password,
  });
  Future<UserCredential> signUp({
    required String email,
    required String password,
  });
  Future<UserCredential> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<User?> reloadCurrentUser();
  Future<String?> getIdToken({bool forceRefresh = false});
  Future<void> signOut();
  Future<void> deleteCurrentAccount({required String password});
}
