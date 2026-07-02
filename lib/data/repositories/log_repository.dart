import 'package:fantastic_guacamole/data/services/logs_service.dart';

class LogRepository {
  LogRepository(this._logsService);

  final ChronoLogsService _logsService;

  Future<List<Map<String, dynamic>>> getLogs() async {
    final ChronoLogsPayload payload = await _logsService.load();
    final DateTime now = DateTime.now().toUtc();

    final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];

    void addAll(String source, List<String> values) {
      for (int i = 0; i < values.length; i++) {
        entries.add(<String, dynamic>{
          'id': '$source-$i',
          'source': source,
          'message': values[i],
          'timestamp': now.toIso8601String(),
        });
      }
    }

    addAll('completed_tasks', payload.completedTasks);
    addAll('past_missions', payload.pastMissions);
    addAll('past_schedules', payload.pastSchedules);
    addAll('notes', payload.notes);
    addAll('daily_logs', payload.dailyLogs);
    addAll('archived_events', payload.archivedEvents);
    addAll('old_routines', payload.oldRoutines);
    addAll('archives', payload.archives);

    return entries;
  }
}
