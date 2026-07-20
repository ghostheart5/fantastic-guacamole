import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/permissions/auth_permission.dart';

class AuthGuard {
  const AuthGuard();

  bool canAccess(AuthUserEntity? user, AuthPermission permission) {
    if (user == null) {
      return permission == AuthPermission.signIn || permission == AuthPermission.signUp;
    }
    if (permission == AuthPermission.signIn || permission == AuthPermission.signUp) {
      return false;
    }
    return true;
  }

  bool sessionIsValid(AuthSessionEntity? session) {
    return session != null && !session.isExpired;
  }
}
