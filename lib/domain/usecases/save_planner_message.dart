import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Resolved by smartPlannerQueryController.
class SavePlannerMessage {
  const SavePlannerMessage(this._repository);

  final IExtendedDomainRepository _repository;

  Future<void> call(PlannerMessage entity) =>
      _repository.savePlannerMessage(entity);
}
