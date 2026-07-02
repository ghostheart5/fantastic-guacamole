import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';

class UpdateProfile {
  UpdateProfile(this.repository);

  final IProfileRepository repository;

  Future<void> call(ProfileEntity profile) {
    return repository.saveProfile(profile);
  }
}
