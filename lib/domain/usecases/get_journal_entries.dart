import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Journal
///
/// Extended-domain read. Registered as getJournalEntriesUseCaseProvider.
class GetJournalEntries {
  const GetJournalEntries(this._repository);

  final IExtendedDomainRepository _repository;

  List<JournalEntry> call() => _repository.getJournalEntries();
}
