import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';

class GetLogs {
  const GetLogs(this.repository);

  final ILogRepository repository;

  Future<List<LogEntryEntity>> call() {
    return repository.getLogs();
  }
}
