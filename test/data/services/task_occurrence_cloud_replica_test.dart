import 'package:fantastic_guacamole/data/services/task_occurrence_cloud_replica.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud row identity separates transitions and preserves series', () {
    final TaskOccurrence occurrence = TaskOccurrence(
      taskId: 'task::next::slot-2',
      seriesId: 'task',
      occurrenceKey: 'slot-2',
      initialScheduledFor: DateTime.utc(2026, 8, 19, 9),
    );
    final TaskOccurrenceTransition first = TaskOccurrenceTransition(
      operationId: 'reschedule-1',
      outcome: TaskOccurrenceOutcome.rescheduled,
      at: DateTime.utc(2026, 8, 19, 10),
      rescheduledFor: DateTime.utc(2026, 8, 19, 12),
    );
    final TaskOccurrenceTransition second = TaskOccurrenceTransition(
      operationId: 'reschedule-2',
      outcome: TaskOccurrenceOutcome.rescheduled,
      at: DateTime.utc(2026, 8, 19, 11),
      rescheduledFor: DateTime.utc(2026, 8, 19, 13),
    );

    final Map<String, dynamic> firstRow = TaskOccurrenceCloudRowMapper.toRow(
      expectedUserId: 'account-a',
      occurrence: occurrence,
      transition: first,
    );
    final Map<String, dynamic> secondRow = TaskOccurrenceCloudRowMapper.toRow(
      expectedUserId: 'account-a',
      occurrence: occurrence,
      transition: second,
    );

    expect(firstRow['id'], isNot(secondRow['id']));
    expect(firstRow['series_id'], 'task');
    expect(firstRow['task_id'], 'task::next::slot-2');
    expect(firstRow['operation_id'], 'reschedule-1');
    expect(firstRow['user_id'], 'account-a');
  });
}
