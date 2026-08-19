import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Reflection
///
/// Extended-domain read. Registered as getReflectionEntriesUseCaseProvider.
class GetReflectionEntries {
  const GetReflectionEntries(this._repository);

  final IExtendedDomainRepository _repository;

  List<ReflectionEntry> call() => _repository.getReflectionEntries();
}
