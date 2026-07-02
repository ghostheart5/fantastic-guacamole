import 'package:fantastic_guacamole/domain/entities/user_entity.dart';
import 'package:fantastic_guacamole/data/models/user_state.dart';
import 'package:fantastic_guacamole/features/user/models/user_model.dart';

class UserAdapter {
  static UserEntity toEntity(UserModel model) => UserEntity(
    id: model.id,
    name: model.name,
    avatarUrl: model.avatarUrl,
    preferences: model.preferences,
  );

  static UserModel toModel(UserEntity entity) => UserModel(
    id: entity.id,
    name: entity.name,
    avatarUrl: entity.avatarUrl,
    preferences: entity.preferences,
  );

  static Map<String, dynamic> toJson(UserModel model) => model.toJson();

  static UserModel fromJson(Map<String, dynamic> json) =>
      UserModel.fromJson(json);

  static UserState stateFromJson(Map<String, dynamic> json) =>
      UserState.fromJson(json);

  static Map<String, dynamic> stateToJson(UserState state) => state.toJson();
}
