import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_profile_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Progression
///
/// No provider yet; the shipping profile write is ProfileController.
class UpdateProfile {
  UpdateProfile(this.repository);

  final IProfileRepository repository;

  Future<void> call(ProfileEntity profile) {
    return repository.saveProfile(profile);
  }
}
