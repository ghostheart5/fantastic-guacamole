import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';

class AddLogEntry {
  const AddLogEntry(this.repository);

  final ILogRepository repository;

  Future<void> call(LogEntryEntity entry) {
    entry.validate(); // optional
    return repository.addLog(entry);
  }
}
