import 'package:fantastic_guacamole/domain/entities/task_occurrence_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task occurrence authority and write-step contract are explicit', () {
    expect(TaskOccurrenceContract.authority, 'active-replication');
    expect(TaskOccurrenceContract.localStore, contains('task_occurrences_v2'));
    expect(TaskOccurrenceContract.remoteTable, 'public.task_occurrences');
    expect(TaskOccurrenceContract.writeSteps, <String>[
      'pending-ledger',
      'task-state',
      'successor-task',
      'final-ledger',
    ]);
  });

  test('crash convergence and SQL mapping cover the required boundaries', () {
    expect(
      TaskOccurrenceContract.crashConvergence.keys,
      containsAll(<String>[
        'before-pending-ledger',
        'after-pending-ledger',
        'after-task-state',
        'after-successor-task',
        'after-final-ledger',
      ]),
    );
    expect(
      TaskOccurrenceContract.localToSqlMapping.keys,
      containsAll(<String>[
        'row_id',
        'operation_id',
        'resolved_at',
        'rescheduled_to',
        'pending_state',
        'validation',
      ]),
    );
  });

  test('timezone semantics cover DST, travel, and timezone changes', () {
    expect(
      TaskOccurrenceContract.timezoneSemantics.keys,
      containsAll(<String>[
        'owner',
        'persistence',
        'dst-gap',
        'dst-overlap',
        'travel',
        'timezone-change',
      ]),
    );
  });

  test(
    'offline order, account transition, and series identity are defined',
    () {
      expect(TaskOccurrenceContract.occurrenceOfflineOrder, <String>[
        'pending-ledger',
        'task-state',
        'successor-task',
        'final-ledger',
        'cloud-replica-upsert',
      ]);
      expect(
        TaskOccurrenceContract.accountTransitionMatrix.keys,
        containsAll(TaskOccurrenceContract.crashConvergence.keys),
      );
      expect(
        TaskOccurrenceContract.seriesIdentity.keys,
        containsAll(<String>[
          'series_id',
          'task_instance_id',
          'occurrence_key',
          'operation_id',
        ]),
      );
    },
  );
}
