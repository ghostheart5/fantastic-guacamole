import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';

abstract class AuthLocalDataSource {
  Future<AuthSessionEntity?> getCachedSession();
  Future<void> cacheSession(AuthSessionEntity? session);
  Future<void> clearSession();
}
