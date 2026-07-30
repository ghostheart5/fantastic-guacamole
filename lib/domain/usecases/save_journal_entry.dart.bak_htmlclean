import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

class SaveJournalEntry {
  const SaveJournalEntry(this._repository);

  final IExtendedDomainRepository _repository;

  Future<void> call(JournalEntry entity) =>
      _repository.saveJournalEntry(entity);
}
