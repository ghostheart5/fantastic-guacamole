import 'package:fantastic_guacamole/domain/entities/identity_profile_entity.dart';

abstract class IIdentityRepository {
  Future<String?> getIdentityId();
  Future<void> saveIdentityId(String id);
  Future<IdentityProfileEntity?> getIdentityProfile();
  Future<void> saveIdentityProfile(IdentityProfileEntity profile);
}
