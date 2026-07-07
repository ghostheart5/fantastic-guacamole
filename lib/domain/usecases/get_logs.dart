import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_log_repository.dart';
import 'package:fantastic_guacamole/domain/models/paged_result.dart';

class GetLogs {
  const GetLogs(this.repository);

  final ILogRepository repository;

  Future<List<LogEntryEntity>> call() {
    return repository.getLogs();
  }

  Future<PagedResult<LogEntryEntity>> page({String? cursor, int limit = 50}) async {
    final List<LogEntryEntity> logs = await repository.getLogs();
    final int safeLimit = limit < 1 ? 1 : limit;
    final int startIndex = cursor == null
        ? 0
        : logs.indexWhere((LogEntryEntity entry) => entry.id == cursor) + 1;
    if (startIndex >= logs.length) {
      return const PagedResult<LogEntryEntity>(items: <LogEntryEntity>[], nextCursor: null);
    }
    final List<LogEntryEntity> page = logs.skip(startIndex).take(safeLimit).toList(growable: false);
    final int nextIndex = startIndex + page.length;
    final String? nextCursor = nextIndex < logs.length && page.isNotEmpty ? page.last.id : null;
    return PagedResult<LogEntryEntity>(items: page, nextCursor: nextCursor);
  }
}
