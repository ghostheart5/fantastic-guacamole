part of 'backup_service.dart';

class BackupRestoreRollbackException implements Exception {
  const BackupRestoreRollbackException({
    required this.restoreErrorType,
    required this.rollbackErrorType,
  });

  final String restoreErrorType;
  final String rollbackErrorType;

  @override
  String toString() =>
      'Backup restore failed and rollback could not complete '
      '(restore: $restoreErrorType, rollback: $rollbackErrorType).';
}

class BackupRestoreCancelledException implements Exception {
  const BackupRestoreCancelledException();

  @override
  String toString() => 'Backup restore was cancelled before commit.';
}

class BackupConcurrentMutationException implements Exception {
  const BackupConcurrentMutationException();

  @override
  String toString() => 'Account data changed while backup work was in flight.';
}

class VersionedBackupSnapshot {
  const VersionedBackupSnapshot(this.payload, this.localGeneration);

  final Map<String, dynamic> payload;
  final int localGeneration;
}

class BackupRestorePreview {
  BackupRestorePreview({
    required this.backupVersion,
    required this.createdAt,
    required Map<String, int> recordCounts,
    required List<String> includedDomains,
    required List<String> cloudReplicatedDomains,
    required List<String> excludedDomains,
    required this.isLegacyEnvelope,
  }) : recordCounts = Map<String, int>.unmodifiable(recordCounts),
       includedDomains = List<String>.unmodifiable(includedDomains),
       cloudReplicatedDomains = List<String>.unmodifiable(
         cloudReplicatedDomains,
       ),
       excludedDomains = List<String>.unmodifiable(excludedDomains);

  final String backupVersion;
  final DateTime createdAt;
  final Map<String, int> recordCounts;
  final List<String> includedDomains;
  final List<String> cloudReplicatedDomains;
  final List<String> excludedDomains;
  final bool isLegacyEnvelope;

  int get totalRecordCount =>
      recordCounts.values.fold<int>(0, (int total, int count) => total + count);
}

class _ValidatedFullBackup {
  const _ValidatedFullBackup({
    required this.version,
    required this.createdAt,
    required this.recordCounts,
    required this.tasks,
    required this.goals,
    required this.habits,
    required this.notes,
    required this.taskOccurrences,
    required this.habitOccurrences,
    required this.decisionOutcomes,
    required this.profile,
    required this.settings,
  });

  final String version;
  final DateTime createdAt;
  final Map<String, int> recordCounts;
  final List<TaskEntity> tasks;
  final List<GoalEntity> goals;
  final List<HabitEntity> habits;
  final List<NoteEntity> notes;
  final List<TaskOccurrence> taskOccurrences;
  final List<HabitOccurrenceEntity> habitOccurrences;
  final List<DecisionOutcomeEntity> decisionOutcomes;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic> settings;
}

class _RestoreSnapshot {
  const _RestoreSnapshot({
    required this.tasks,
    required this.goals,
    required this.habits,
    required this.notes,
    required this.taskOccurrences,
    required this.habitOccurrences,
    required this.decisionOutcomes,
    required this.secureProfilePresent,
    required this.secureProfile,
    required this.legacyProfilePresent,
    required this.legacyProfile,
    required this.settings,
  });

  final List<TaskEntity> tasks;
  final List<GoalEntity> goals;
  final List<HabitEntity> habits;
  final List<NoteEntity> notes;
  final List<TaskOccurrence> taskOccurrences;
  final List<HabitOccurrenceEntity> habitOccurrences;
  final List<DecisionOutcomeEntity> decisionOutcomes;
  final bool secureProfilePresent;
  final String? secureProfile;
  final bool legacyProfilePresent;
  final String? legacyProfile;
  final Map<String, Object> settings;
}

class _LegacyRestoreSnapshot {
  const _LegacyRestoreSnapshot({
    required this.tasks,
    required this.secureProfilePresent,
    required this.secureProfile,
    required this.legacyProfilePresent,
    required this.legacyProfile,
    required this.settings,
  });

  final List<TaskEntity> tasks;
  final bool secureProfilePresent;
  final String? secureProfile;
  final bool legacyProfilePresent;
  final String? legacyProfile;
  final Map<String, Object> settings;
}
