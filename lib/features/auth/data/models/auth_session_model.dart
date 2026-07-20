import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_user_model.dart';

class AuthSessionModel extends AuthSessionEntity {
  const AuthSessionModel({
    required super.accessToken,
    required super.refreshToken,
    required super.expiresAt,
    required super.user,
    required super.issuedAt,
  });

  factory AuthSessionModel.fromEntity(AuthSessionEntity entity) {
    return AuthSessionModel(
      accessToken: entity.accessToken,
      refreshToken: entity.refreshToken,
      expiresAt: entity.expiresAt,
      user: AuthUserModel.fromEntity(entity.user),
      issuedAt: entity.issuedAt,
    );
  }

  factory AuthSessionModel.fromMap(Map<String, dynamic> map) {
    return AuthSessionModel(
      accessToken: (map['accessToken'] ?? '').toString(),
      refreshToken: (map['refreshToken'] ?? '').toString(),
      expiresAt: DateTime.tryParse((map['expiresAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      issuedAt: DateTime.tryParse((map['issuedAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      user: AuthUserModel.fromMap(Map<String, dynamic>.from(map['user'] as Map? ?? <String, dynamic>{})),
    );
  }


  AuthSessionEntity toEntity() => AuthSessionEntity.fromMap(toMap());
}
