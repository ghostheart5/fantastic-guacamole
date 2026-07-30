import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';

class SaveIdentityProfile {
  const SaveIdentityProfile(this._repository);

  final IIdentityRepository _repository;

  Future<void> call(IdentityProfileEntity profile) =>
      _repository.saveIdentityProfile(profile);
}
