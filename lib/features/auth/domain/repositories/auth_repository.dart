import 'package:fantastic_guacamole/features/auth/domain/core/result.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/email_address.dart';
import 'package:fantastic_guacamole/features/auth/domain/value_objects/password_value.dart';

abstract class AuthRepository {
  Stream<Result<AuthSessionEntity?>> watchSession();
  Future<Result<AuthSessionEntity?>> getCurrentSession();
  Future<Result<AuthUserEntity?>> getCurrentUser();
  Future<Result<AuthSessionEntity?>> signInWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  });
  Future<Result<AuthSessionEntity?>> signUpWithEmail({
    required EmailAddress email,
    required PasswordValue password,
  });
  Future<Result<AuthSessionEntity?>> signInWithGoogle();
  Future<Result<AuthSessionEntity?>> signInWithGitHub();
  Future<Result<void>> sendPasswordReset({required EmailAddress email});
  Future<Result<void>> sendEmailVerification();
  Future<Result<void>> refreshSession();
  Future<Result<void>> signOut();
  Future<Result<void>> deleteAccount({required PasswordValue password});
}
