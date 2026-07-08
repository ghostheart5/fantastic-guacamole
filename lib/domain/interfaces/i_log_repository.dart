import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';

abstract class ILogRepository {
  Future<List<LogEntryEntity>> getLogs();

  Future<void> addLog(LogEntryEntity entry);
}
