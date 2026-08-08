import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Resolved by coachQueryController.
class SaveCoachMessage {
  const SaveCoachMessage(this._repository);

  final IExtendedDomainRepository _repository;

  Future<void> call(CoachMessage entity) =>
      _repository.saveCoachMessage(entity);
}
