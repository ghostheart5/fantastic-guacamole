import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

class GetJournalEntries {
  const GetJournalEntries(this._repository);

  final IExtendedDomainRepository _repository;

  List<JournalEntry> call() => _repository.getJournalEntries();
}
