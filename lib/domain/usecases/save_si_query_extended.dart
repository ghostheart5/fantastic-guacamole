import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Extended-domain write. Registered as saveSiQueryExtendedUseCaseProvider.
class SaveSiQueryExtended {
  const SaveSiQueryExtended(this._repository);

  final IExtendedDomainRepository _repository;

  Future<void> call(SiQuery entity) => _repository.saveSiQuery(entity);
}
