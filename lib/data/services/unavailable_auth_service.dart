import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';

class UnavailableAuthService implements AuthServiceContract {
  const UnavailableAuthService({this.message = 'Authentication backend is unavailable.'});

  final String message;

  FirebaseAuthException _error() {
    return FirebaseAuthException(code: 'auth-unavailable', message: message);
  }

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signIn({required String email, required String password}) async {
    throw _error();
  }

  @override
  Future<UserCredential> signUp({required String email, required String password}) async {
    throw _error();
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    throw _error();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw _error();
  }

  @override
  Future<void> sendEmailVerification() async {
    throw _error();
  }

  @override
  Future<User?> reloadCurrentUser() async {
    return null;
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    throw _error();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    throw _error();
  }
}
