import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Stream<AuthSessionModel?> watchSession();
  Future<AuthSessionModel?> getCurrentSession();
  Future<AuthSessionModel?> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  });
  Future<AuthSessionModel?> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  });
  Future<AuthSessionModel?> signInWithGoogle();
  Future<AuthSessionModel?> signInWithGitHub();
  Future<void> sendPasswordReset({required EmailAddress email});
  Future<void> sendEmailVerification();
  Future<void> refreshSession();
  Future<void> signOut();
  Future<void> deleteAccount({required PasswordValue password});
}
