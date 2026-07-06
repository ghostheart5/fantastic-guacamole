import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_identity_repository.dart';

class GetIdentityProfile {
  const GetIdentityProfile(this._repository);

  final IIdentityRepository _repository;

  Future<IdentityProfileEntity?> call() => _repository.getIdentityProfile();
}
