import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';

class GetProfile {
  GetProfile(this.repository);

  final IProfileRepository repository;

  Future<ProfileEntity?> call() {
    return repository.getProfile();
  }
}
