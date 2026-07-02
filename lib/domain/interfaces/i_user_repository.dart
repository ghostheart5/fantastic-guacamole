import 'package:fantastic_guacamole/domain/entities/user_entity.dart';

abstract class IUserRepository {
  Future<UserEntity?> getUser();
  Future<void> updateUser(UserEntity user);
}
