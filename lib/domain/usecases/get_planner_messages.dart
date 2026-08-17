import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: SI Console
///
/// Extended-domain read. Registered as getPlannerMessagesUseCaseProvider.
class GetPlannerMessages {
  const GetPlannerMessages(this._repository);

  final IExtendedDomainRepository _repository;

  List<PlannerMessage> call() => _repository.getPlannerMessages();
}
