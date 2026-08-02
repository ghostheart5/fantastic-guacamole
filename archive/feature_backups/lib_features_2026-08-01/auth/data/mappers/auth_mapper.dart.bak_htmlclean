import 'package:fantastic_guacamole/features/auth/domain/entities/auth_session_entity.dart';
import 'package:fantastic_guacamole/features/auth/domain/entities/auth_user_entity.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_session_model.dart';
import 'package:fantastic_guacamole/features/auth/data/models/auth_user_model.dart';

extension AuthUserEntityMapper on AuthUserEntity {
  AuthUserModel toModel() => AuthUserModel.fromEntity(this);
}

extension AuthUserModelMapper on AuthUserModel {
  AuthUserEntity toDomain() => toEntity();
}

extension AuthSessionEntityMapper on AuthSessionEntity {
  AuthSessionModel toModel() => AuthSessionModel.fromEntity(this);
}

extension AuthSessionModelMapper on AuthSessionModel {
  AuthSessionEntity toDomain() => toEntity();
}
