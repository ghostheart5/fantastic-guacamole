import 'package:firebase_auth/firebase_auth.dart';

import 'operation_cancellation.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth}) : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    cancellationToken.throwIfCancelled();
    return credential;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    cancellationToken.throwIfCancelled();
    return credential;
  }

  Future<void> sendPasswordReset(String email, {CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    await _auth.sendPasswordResetEmail(email: email);
    cancellationToken.throwIfCancelled();
  }

  Future<void> signOut({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    await _auth.signOut();
    cancellationToken.throwIfCancelled();
  }
}
