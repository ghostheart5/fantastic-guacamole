import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';

class AuthUserModel extends AuthUserEntity {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.displayName,
    required super.emailVerified,
    required super.isAnonymous,
    super.avatarUrl,
    super.roles = const <String>[],
  });

  factory AuthUserModel.fromEntity(AuthUserEntity entity) {
    return AuthUserModel(
      id: entity.id,
      email: entity.email,
      displayName: entity.displayName,
      emailVerified: entity.emailVerified,
      isAnonymous: entity.isAnonymous,
      avatarUrl: entity.avatarUrl,
      roles: entity.roles,
    );
  }

  factory AuthUserModel.fromMap(Map<String, dynamic> map) {
    return AuthUserModel(
      id: (map['id'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      emailVerified: map['emailVerified'] == true,
      isAnonymous: map['isAnonymous'] == true,
      avatarUrl: map['avatarUrl']?.toString(),
      roles: (map['roles'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic role) => role.toString())
          .toList(growable: false),
    );
  }


  AuthUserEntity toEntity() => AuthUserEntity.fromMap(toMap());
}
