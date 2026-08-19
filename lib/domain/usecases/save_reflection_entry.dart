import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Reflection
///
/// Extended-domain write. Registered as saveReflectionEntryUseCaseProvider.
class SaveReflectionEntry {
  const SaveReflectionEntry(this._repository);

  final IExtendedDomainRepository _repository;

  Future<void> call(ReflectionEntry entity) =>
      _repository.saveReflectionEntry(entity);
}
