import 'package:fantastic_guacamole/domain/entities/profile_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Progression
///
/// Bound to ProfileRepository; ProfileController is the shipping profile state.
abstract class IProfileRepository {
  Future<ProfileEntity?> getProfile();
  Future<void> saveProfile(ProfileEntity profile);
}
