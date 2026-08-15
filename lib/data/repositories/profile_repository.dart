import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';

class ProfileRepository implements IProfileRepository {
  ProfileRepository({
    required this.readCurrent,
    required this.writeCurrent,
  });

  final Future<ProfileEntity?> Function() readCurrent;
  final Future<void> Function(ProfileEntity profile) writeCurrent;

  @override
  Future<ProfileEntity?> getProfile() => readCurrent();

  @override
  Future<void> saveProfile(ProfileEntity profile) => writeCurrent(profile);
}
