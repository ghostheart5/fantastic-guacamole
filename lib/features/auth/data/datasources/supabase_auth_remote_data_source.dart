import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/contracts/auth_service_contract.dart';
import 'package:fantastic_guacamole/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_session_model.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_user_model.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';

class SupabaseAuthRemoteDataSource implements AuthRemoteDataSource {
  SupabaseAuthRemoteDataSource({required AuthServiceContract authService})
    : this._(authService);

  SupabaseAuthRemoteDataSource._(this._authService);

  final AuthServiceContract _authService;

  @override
  Stream<AuthSessionModel?> watchSession() {
    return _authService.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        return null;
      }
      return getCurrentSession();
    });
  }

  @override
  Future<AuthSessionModel?> getCurrentSession() async {
    final User? user = _authService.currentUser;
    if (user == null) {
      return null;
    }
    final AuthSessionSnapshot? session = await _authService
        .getCurrentSessionSnapshot();
    if (session == null || session.accessToken.isEmpty) {
      return null;
    }
    return AuthSessionModel(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
      user: _mapUser(user),
      issuedAt: session.issuedAt,
    );
  }

  @override
  Future<AuthSessionModel?> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    await _authService.signIn(
      email: email.value,
      password: password.value,
    );
    return getCurrentSession();
  }

  @override
  Future<AuthSessionModel?> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  }) async {
    await _authService.signUp(
      email: email.value,
      password: password.value,
    );
    return getCurrentSession();
  }

  @override
  Future<AuthSessionModel?> signInWithGoogle() async {
    await _authService.signInWithGoogle();
    return getCurrentSession();
  }

  @override
  Future<AuthSessionModel?> signInWithGitHub() async {
    await _authService.signInWithGitHub();
    return getCurrentSession();
  }

  @override
  Future<void> sendEmailVerification() {
    return _authService.sendEmailVerification();
  }

  @override
  Future<void> sendPasswordReset({required EmailAddress email}) {
    return _authService.sendPasswordReset(email.value);
  }

  @override
  Future<void> refreshSession() {
    return _authService.reloadCurrentUser().then((_) => null);
  }

  @override
  Future<void> signOut() {
    return _authService.signOut();
  }

  @override
  Future<void> deleteAccount({required PasswordValue password}) {
    return _authService.deleteCurrentAccount(password: password.value);
  }

  AuthUserEntity _mapUser(User user) {
    return AuthUserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email ?? 'User',
      emailVerified: user.emailVerified,
      isAnonymous: false,
    ).toEntity();
  }
}
