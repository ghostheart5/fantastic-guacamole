import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth}) : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({required String email, required String password}) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp({required String email, required String password}) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Returns a valid Firebase ID token, force-refreshing if the current token
  /// expires within the next 5 minutes.
  Future<String?> getValidIdToken() async {
    String? token = await _auth.currentUser?.getIdToken();
    if (token == null) return null;

    final DateTime? expiration = _getTokenExpiration(token);
    if (expiration != null &&
        DateTime.now().add(const Duration(minutes: 5)).isAfter(expiration)) {
      token = await _auth.currentUser?.getIdToken(true);
    }
    return token;
  }

  /// Decodes the JWT payload and returns the [exp] field as a [DateTime].
  /// Returns `null` if the token cannot be parsed.
  DateTime? _getTokenExpiration(String jwt) {
    try {
      final List<String> parts = jwt.split('.');
      if (parts.length != 3) return null;

      final String payload = parts[1];
      // Restore Base64 padding so the decoder doesn't reject the string.
      final String padded = payload + ('=' * ((4 - payload.length % 4) % 4));
      final List<int> bytes = base64Url.decode(padded);
      final Map<String, dynamic> decoded =
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      final int? exp = decoded['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null; // Can't parse; assume valid.
    }
  }
}
