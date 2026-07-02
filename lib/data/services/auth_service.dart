import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthService implements AuthServiceContract {
  AuthService({required sb.SupabaseClient supabaseClient, required this._store})
    : _auth = supabaseClient;

  final sb.SupabaseClient _auth;
  final SecureStore _store;
  int _failedSignInAttempts = 0;
  DateTime? _signInBlockedUntil;

  @override
  Stream<User?> authStateChanges() {
    return _auth.auth.onAuthStateChange.map((sb.AuthState state) => _mapUser(state.session?.user));
  }

  @override
  User? get currentUser => _mapUser(_auth.auth.currentUser);

  @override
  Future<UserCredential> signIn({required String email, required String password}) async {
    final DateTime now = DateTime.now();
    final DateTime? blockedUntil = _signInBlockedUntil;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      throw FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many sign-in attempts. Please wait and try again.',
      );
    }
    try {
      final sb.AuthResponse response = await _auth.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final UserCredential credential = UserCredential(user: _mapUser(response.user));
      _failedSignInAttempts = 0;
      _signInBlockedUntil = null;
      return credential;
    } on sb.AuthException catch (error) {
      final FirebaseAuthException mapped = _mapAuthException(error);
      if (_isCredentialFailure(mapped.code)) {
        _failedSignInAttempts += 1;
        final int seconds = (2 << (_failedSignInAttempts > 5 ? 5 : _failedSignInAttempts)).clamp(
          2,
          60,
        );
        _signInBlockedUntil = now.add(Duration(seconds: seconds));
      }
      throw mapped;
    } on Exception {
      throw FirebaseAuthException(
        code: 'auth-unavailable',
        message: 'Authentication backend is unavailable.',
      );
    }
  }

  @override
  Future<UserCredential> signUp({required String email, required String password}) async {
    try {
      final sb.AuthResponse response = await _auth.auth.signUp(email: email, password: password);
      return UserCredential(user: _mapUser(response.user));
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    }
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    try {
      await _auth.auth.signInWithOAuth(sb.OAuthProvider.google);
      return UserCredential(user: currentUser);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final User? user = currentUser;
    final String email = user?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No signed-in user found.');
    }
    try {
      await _auth.auth.resend(type: sb.OtpType.signup, email: email);
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    }
  }

  @override
  Future<User?> reloadCurrentUser() async {
    try {
      await _auth.auth.refreshSession();
      return currentUser;
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _auth.auth.refreshSession();
      }
      return _auth.auth.currentSession?.accessToken;
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.auth.signOut();
  }

  @override
  Future<void> deleteCurrentAccount({required String password}) async {
    final User? user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No signed-in user found.');
    }
    final String email = user.email?.trim() ?? '';
    if (email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Current account email is unavailable.',
      );
    }
    if (password.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-password',
        message: 'Password is required to delete this account.',
      );
    }

    try {
      await _auth.auth.signInWithPassword(email: email, password: password);
      throw FirebaseAuthException(
        code: 'operation-not-supported',
        message: 'Direct account deletion requires a secure server endpoint.',
      );
    } on sb.AuthException catch (error) {
      throw _mapAuthException(error);
    } finally {
      await _store.deleteAll();
      await _auth.auth.signOut();
    }
  }

  bool _isCredentialFailure(String code) {
    return code == 'wrong-password' ||
        code == 'invalid-credential' ||
        code == 'user-not-found' ||
        code == 'invalid-email';
  }

  User? _mapUser(sb.User? supabaseUser) {
    if (supabaseUser == null) {
      return null;
    }
    final String? email = supabaseUser.email;
    final Map<String, dynamic> metadata = supabaseUser.userMetadata ?? const <String, dynamic>{};
    final String? fullName = metadata['full_name']?.toString().trim();
    final String? name = metadata['name']?.toString().trim();
    final bool verified = supabaseUser.emailConfirmedAt != null;
    return User(
      id: supabaseUser.id,
      email: email,
      displayName: (fullName?.isNotEmpty ?? false)
          ? fullName
          : ((name?.isNotEmpty ?? false) ? name : null),
      emailVerified: verified,
    );
  }

  FirebaseAuthException _mapAuthException(sb.AuthException error) {
    final String rawCode = (error.statusCode ?? '').toString().toLowerCase();
    final String message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return FirebaseAuthException(code: 'wrong-password', message: error.message);
    }
    if (message.contains('email not confirmed')) {
      return FirebaseAuthException(code: 'user-not-verified', message: error.message);
    }
    if (message.contains('already registered') || message.contains('already been registered')) {
      return FirebaseAuthException(code: 'email-already-in-use', message: error.message);
    }
    if (rawCode == '429') {
      return FirebaseAuthException(code: 'too-many-requests', message: error.message);
    }
    if (rawCode == '400' && message.contains('email')) {
      return FirebaseAuthException(code: 'invalid-email', message: error.message);
    }
    if (rawCode == '422' && message.contains('password')) {
      return FirebaseAuthException(code: 'weak-password', message: error.message);
    }
    return FirebaseAuthException(code: 'auth-unavailable', message: error.message);
  }
}
