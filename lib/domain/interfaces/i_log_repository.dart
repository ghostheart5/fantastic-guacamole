import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Logs
///
/// Bound to LogRepository.
abstract class ILogRepository {
  Future<List<LogEntryEntity>> getLogs();

  Future<void> addLog(LogEntryEntity entry);
}
