import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';

abstract class IProfileRepository {
  Future<ProfileEntity?> getProfile();
  Future<void> saveProfile(ProfileEntity profile);
}
