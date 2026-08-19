class TaskOccurrenceContract {
  const TaskOccurrenceContract._();

  static const String authority = 'active-replication';
  static const String localStore = 'account-scoped Hive task_occurrences_v2';
  static const String remoteTable = 'public.task_occurrences';

  static const List<String> writeSteps = <String>[
    'pending-ledger',
    'task-state',
    'successor-task',
    'final-ledger',
  ];

  static const Map<String, String> crashConvergence = <String, String>{
    'before-pending-ledger':
        'No occurrence is committed. Retry is user-triggered by tapping complete/skip/reschedule again.',
    'after-pending-ledger':
        'Pending operation remains local. Recovery is automatic on retry and must reuse the pending operation.',
    'after-task-state':
        'Task may show the outcome before the ledger is final. Recovery is automatic on retry and finalizes the same operation.',
    'after-successor-task':
        'Recurring successor may already exist. Recovery is automatic on retry and must not create a second successor.',
    'after-final-ledger':
        'Outcome is terminal. Duplicate retries are idempotent and cannot emit one-time side effects again.',
  };

  static const Map<String, String> timezoneSemantics = <String, String>{
    'owner':
        'The occurrence stores the user-visible wall-clock schedule identity from the task at mutation time.',
    'persistence':
        'Local and SQL rows persist instant timestamps as UTC ISO-8601/timestamptz values.',
    'dst-gap':
        'A nonexistent local wall-clock time must resolve to the next valid local instant before occurrence mutation.',
    'dst-overlap':
        'An ambiguous repeated local time keeps the selected instant; replay equality uses operationId and occurrenceKey, not formatted clock text.',
    'travel':
        'Travel changes future display and planning context but does not rewrite committed occurrence keys.',
    'timezone-change':
        'Device timezone changes must not mutate committed occurrence identity or SQL replay equality.',
  };

  static const Map<String, String> localToSqlMapping = <String, String>{
    'row_id':
        'TaskOccurrence.id -> task_occurrences.id; unique inside user_id.',
    'operation_id':
        'TaskOccurrenceTransition.operationId -> operation_id; duplicate operation IDs replay idempotently.',
    'task_id': 'TaskOccurrence.taskId -> task_id.',
    'occurrence_key': 'TaskOccurrence.occurrenceKey -> occurrence_key.',
    'resolved_at': 'TaskOccurrenceTransition.at UTC -> resolved_at.',
    'rescheduled_to':
        'TaskOccurrenceTransition.rescheduledFor UTC -> rescheduled_to.',
    'original_schedule_identity':
        'TaskOccurrence.initialScheduledFor UTC -> original_schedule_identity.',
    'pending_state':
        'pendingOperation is local-only recovery state and is never replicated as a committed SQL row.',
    'validation':
        'Blank IDs/keys and unknown outcomes are invalid locally; SQL check constraints repeat the fail-closed contract.',
  };

  static const List<String> occurrenceOfflineOrder = <String>[
    'pending-ledger',
    'task-state',
    'successor-task',
    'final-ledger',
    'cloud-replica-upsert',
  ];

  static const Map<String, String> accountTransitionMatrix = <String, String>{
    'before-pending-ledger':
        'Transition waits for coordinator drain; no mutation should start while storage scope is unsafe.',
    'after-pending-ledger':
        'Transition drain waits for the queued mutation. If interrupted by process death, retry resumes from pending state.',
    'after-task-state':
        'Transition drain waits for final ledger. If process death occurs, next owner-safe launch retries/finalizes.',
    'after-successor-task':
        'Transition drain waits for final ledger and must not duplicate successor on retry.',
    'after-final-ledger':
        'Transition may proceed after read-model invalidation; duplicate actions are idempotent.',
  };

  static const Map<String, String> seriesIdentity = <String, String>{
    'series_id':
        'Stable recurring-series identity. Required for future multi-device recurrence editing; do not derive it from one task instance.',
    'task_instance_id': 'Concrete task row for one visible scheduled item.',
    'occurrence_key':
        'Stable actionable slot identity for one scheduled occurrence.',
    'operation_id':
        'Idempotency identity for one user action against one occurrence.',
  };
}
