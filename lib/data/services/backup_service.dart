import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/note_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';

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

class BackupService {
  BackupService({
    required this.taskRepository,
    required this.profileStorage,
    required this.prefs,
    this.scope,
    this.goalRepository,
    this.habitRepository,
    this.noteRepository,
    this.taskOccurrenceRepository,
    this.habitOccurrenceRepository,
    this.decisionOutcomeRepository,
    this.secureProfileStore,
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _mutationCoordinator =
           mutationCoordinator ?? KeyedMutationCoordinator.shared;

  static const String _profileStateKey = 'profile_state';
  static const String _backupVersion = '5.0.0';
  static const Set<String> _legacyBackupVersions = <String>{'3.0.0', '4.0.0'};
  static const int _maxTaskRecords = 10000;
  static const int _maxDomainRecords = 10000;
  static const int _maxTaskIdLength = 256;
  static const int _maxTaskTitleLength = 4096;
  static const int _maxTaskDescriptionLength = 100000;
  static const int _maxSubtasksPerTask = 1000;

  final ITaskRepository taskRepository;
  final AccountStorageScope? scope;
  final IGoalRepository? goalRepository;
  final IHabitRepository? habitRepository;
  final INoteRepository? noteRepository;
  final TaskOccurrenceRepository? taskOccurrenceRepository;
  final HabitOccurrenceRepository? habitOccurrenceRepository;
  final IDecisionOutcomeRepository? decisionOutcomeRepository;
  final HiveStorage<String> profileStorage;
  final SharedPrefsStorage prefs;
  final SecureStore? secureProfileStore;
  final KeyedMutationCoordinator _mutationCoordinator;
  static const String _secureProfileStateKey = 'profile_state_v2';

  Future<Map<String, dynamic>> createFullBackup() async {
    _requireCompleteLocalContinuity();
    final List<TaskEntity> tasks = await taskRepository.getAllTasks();
    final List<GoalEntity> goals = _readGoalsForBackup();
    final List<HabitEntity> habits = await habitRepository!.getHabits();
    final List<NoteEntity> notes = await _readNotesForBackup();
    final List<TaskOccurrence> taskOccurrences = await taskOccurrenceRepository!
        .listOccurrences();
    final List<HabitOccurrenceEntity> habitOccurrences =
        await habitOccurrenceRepository!.load();
    final List<DecisionOutcomeEntity> decisionOutcomes =
        await decisionOutcomeRepository!.load();
    final Map<String, dynamic>? profile = _decodeProfile(await _readProfile());
    final Map<String, dynamic> settings = _readAccountSettings();

    return <String, dynamic>{
      'version': _backupVersion,
      'manifest': accountDataBackupManifest(),
      'account': _accountEnvelope(),
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskEntityMapper.toJson).toList(),
      'goals': goals.map((GoalEntity value) => value.toJson()).toList(),
      'habits': habits.map((HabitEntity value) => value.toJson()).toList(),
      'notes': notes.map((NoteEntity value) => value.toJson()).toList(),
      'taskOccurrences': taskOccurrences
          .map((TaskOccurrence value) => value.toJson())
          .toList(),
      'habitOccurrences': habitOccurrences
          .map((HabitOccurrenceEntity value) => value.toJson())
          .toList(),
      'decisionOutcomes': decisionOutcomes
          .map((DecisionOutcomeEntity value) => value.toJson())
          .toList(),
      'profile': profile,
      'settings': settings,
      'recordCounts': _recordCounts(
        taskCount: tasks.length,
        goalCount: goals.length,
        habitCount: habits.length,
        noteCount: notes.length,
        taskOccurrenceCount: taskOccurrences.length,
        habitOccurrenceCount: habitOccurrences.length,
        decisionOutcomeCount: decisionOutcomes.length,
        profile: profile,
        settings: settings,
      ),
    };
  }

  Future<VersionedBackupSnapshot> createVersionedFullBackup() async {
    late Map<String, dynamic> payload;
    await runAccountStorageMutation(
      () async => payload = await _createContainedCloudBackup(),
      coordinator: _mutationCoordinator,
    );
    return VersionedBackupSnapshot(
      payload,
      _mutationCoordinator.generationFor(accountStorageMutationKey),
    );
  }

  Future<Map<String, dynamic>> _createContainedCloudBackup() async {
    final List<TaskEntity> tasks = await taskRepository.getAllTasks();
    final Map<String, dynamic>? profile = _decodeProfile(await _readProfile());
    final Map<String, dynamic> settings = _readAccountSettings();
    return <String, dynamic>{
      'version': '4.0.0',
      'manifest': _containedCloudManifest(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map(TaskEntityMapper.toJson).toList(growable: false),
      'profile': profile,
      'settings': settings,
      'recordCounts': <String, int>{
        'tasks': tasks.length,
        'profile': profile == null ? 0 : 1,
        'settings': settings.length,
      },
    };
  }

  Map<String, dynamic> _containedCloudManifest() {
    const Set<String> included = <String>{'tasks', 'profile', 'settings'};
    return <String, dynamic>{
      'manifestVersion': 1,
      'backupKind': 'containedCloudLegacy',
      'cloudCapabilityContained': true,
      'includedDomains': included.toList(growable: false),
      'cloudReplicatedDomains': const <String>[],
      'excludedDomains': accountDataDomains
          .where((AccountDataDomain domain) => !included.contains(domain.id))
          .map((AccountDataDomain domain) => domain.id)
          .toList(growable: false),
      'domains': accountDataDomains
          .map((AccountDataDomain domain) {
            final Map<String, dynamic> value = domain.toManifestJson();
            final bool isIncluded = included.contains(domain.id);
            value['backupStatus'] = isIncluded ? 'backedUp' : 'localOnly';
            value['portableBackup'] = isIncluded;
            return value;
          })
          .toList(growable: false),
    };
  }

  bool isLocalGenerationCurrent(int generation) {
    return _mutationCoordinator.generationFor(accountStorageMutationKey) ==
        generation;
  }

  int get localGeneration =>
      _mutationCoordinator.generationFor(accountStorageMutationKey);

  Future<Map<String, dynamic>> backupTasks() async {
    final List<TaskEntity> tasks = await taskRepository.getAllTasks();
    return <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskEntityMapper.toJson).toList(),
    };
  }

  Future<Map<String, dynamic>> backupProfile() async {
    return <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'profile': _decodeProfile(await _readProfile()),
    };
  }

  Future<Map<String, dynamic>> backupSettings() async {
    return <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'settings': _readAccountSettings(),
    };
  }

  Future<String> exportFullBackupString() async {
    return jsonEncode(await createFullBackup());
  }

  Future<String> exportTasksString() async {
    return jsonEncode(await backupTasks());
  }

  void validateFullBackup(Map<String, dynamic> backup) {
    _validateFullBackup(backup);
  }

  BackupRestorePreview previewFullRestore(Map<String, dynamic> backup) {
    final _ValidatedFullBackup validated = _validateFullBackup(backup);
    final Map<String, dynamic> manifest = _strictStringKeyMap(
      backup['manifest'],
      field: 'manifest',
    );
    return BackupRestorePreview(
      backupVersion: validated.version,
      createdAt: validated.createdAt,
      recordCounts: validated.recordCounts,
      includedDomains: _strictStringList(
        manifest['includedDomains'],
        field: 'manifest.includedDomains',
      ),
      cloudReplicatedDomains: _strictStringList(
        manifest['cloudReplicatedDomains'],
        field: 'manifest.cloudReplicatedDomains',
      ),
      excludedDomains: _strictStringList(
        manifest['excludedDomains'],
        field: 'manifest.excludedDomains',
      ),
      isLegacyEnvelope: _legacyBackupVersions.contains(validated.version),
    );
  }

  Future<void> restoreFullBackup(
    Map<String, dynamic> backup, {
    bool Function()? canContinue,
    int? expectedLocalGeneration,
  }) async {
    final _ValidatedFullBackup validated = _validateFullBackup(backup);
    if (validated.version != _backupVersion) {
      _requireRestoreLease(canContinue);
      return runAccountStorageMutation(() {
        if (expectedLocalGeneration != null &&
            !isLocalGenerationCurrent(expectedLocalGeneration)) {
          throw const BackupConcurrentMutationException();
        }
        return _restoreValidatedLegacyFullBackup(
          validated,
          canContinue: canContinue,
        );
      }, coordinator: _mutationCoordinator);
    }
    _requireCompleteLocalContinuity();
    _requireRestoreLease(canContinue);
    return runAccountStorageMutation(() {
      if (expectedLocalGeneration != null &&
          !isLocalGenerationCurrent(expectedLocalGeneration)) {
        throw const BackupConcurrentMutationException();
      }
      return _restoreValidatedFullBackup(validated, canContinue: canContinue);
    }, coordinator: _mutationCoordinator);
  }

  Future<void> _restoreValidatedLegacyFullBackup(
    _ValidatedFullBackup validated, {
    bool Function()? canContinue,
  }) async {
    final _LegacyRestoreSnapshot snapshot =
        await _captureLegacyRestoreSnapshot();
    try {
      await _replaceTasks(validated.tasks, canContinue: canContinue);
      _requireRestoreLease(canContinue);
      if (validated.profile == null) {
        await _deleteProfile();
      } else {
        await _writeProfile(jsonEncode(validated.profile));
      }
      _requireRestoreLease(canContinue);
      await _replaceAccountSettings(
        validated.settings,
        canContinue: canContinue,
      );
      _requireRestoreLease(canContinue);
    } on Object catch (restoreError, restoreStack) {
      try {
        await _restoreLegacySnapshot(snapshot);
      } on Object catch (rollbackError) {
        throw BackupRestoreRollbackException(
          restoreErrorType: restoreError.runtimeType.toString(),
          rollbackErrorType: rollbackError.runtimeType.toString(),
        );
      }
      Error.throwWithStackTrace(restoreError, restoreStack);
    }
  }

  Future<void> _restoreValidatedFullBackup(
    _ValidatedFullBackup validated, {
    bool Function()? canContinue,
  }) async {
    _requireRestoreLease(canContinue);
    final _RestoreSnapshot snapshot = await _captureRestoreSnapshot();

    try {
      _requireRestoreLease(canContinue);
      await _replaceTasks(validated.tasks, canContinue: canContinue);
      _requireRestoreLease(canContinue);
      await goalRepository!.saveGoals(validated.goals);
      _requireRestoreLease(canContinue);
      await habitRepository!.saveHabits(validated.habits);
      _requireRestoreLease(canContinue);
      await _replaceNotes(validated.notes);
      _requireRestoreLease(canContinue);
      await taskOccurrenceRepository!.replaceSnapshot(
        validated.taskOccurrences,
      );
      _requireRestoreLease(canContinue);
      await habitOccurrenceRepository!.replaceSnapshot(
        validated.habitOccurrences,
      );
      _requireRestoreLease(canContinue);
      await _replaceDecisionOutcomes(validated.decisionOutcomes);
      _requireRestoreLease(canContinue);
      if (validated.profile == null) {
        await _deleteProfile();
      } else {
        await _writeProfile(jsonEncode(validated.profile));
      }
      _requireRestoreLease(canContinue);
      await _replaceAccountSettings(
        validated.settings,
        canContinue: canContinue,
      );
      _requireRestoreLease(canContinue);
    } on Object catch (restoreError, restoreStack) {
      try {
        await _restoreSnapshot(snapshot);
      } on Object catch (rollbackError) {
        throw BackupRestoreRollbackException(
          restoreErrorType: restoreError.runtimeType.toString(),
          rollbackErrorType: rollbackError.runtimeType.toString(),
        );
      }
      Error.throwWithStackTrace(restoreError, restoreStack);
    }
  }

  Future<void> restoreTasks(
    Map<String, dynamic> backup, {
    bool Function()? canContinue,
  }) async {
    final List<TaskEntity> restoredTasks = _taskEntitiesFromRaw(
      backup['tasks'],
    );
    _requireRestoreLease(canContinue);
    return runAccountStorageMutation(
      () => _restoreValidatedTasks(restoredTasks, canContinue: canContinue),
      coordinator: _mutationCoordinator,
    );
  }

  Future<void> _restoreValidatedTasks(
    List<TaskEntity> restoredTasks, {
    bool Function()? canContinue,
  }) async {
    _requireRestoreLease(canContinue);
    final List<TaskEntity> existing = await taskRepository.getAllTasks();
    try {
      await _replaceTasks(restoredTasks, canContinue: canContinue);
      _requireRestoreLease(canContinue);
    } on Object catch (restoreError, restoreStack) {
      try {
        await _replaceTasks(existing);
      } on Object catch (rollbackError) {
        throw BackupRestoreRollbackException(
          restoreErrorType: restoreError.runtimeType.toString(),
          rollbackErrorType: rollbackError.runtimeType.toString(),
        );
      }
      Error.throwWithStackTrace(restoreError, restoreStack);
    }
  }

  Future<void> restoreProfile(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? profile =
        _asStringKeyMap(backup['profile']) ??
        _profileFromLegacyUser(backup['user']);
    if (profile == null) {
      throw const FormatException('Backup profile must be a JSON object.');
    }
    await runAccountStorageMutation(
      () => _writeProfile(jsonEncode(profile)),
      coordinator: _mutationCoordinator,
    );
  }

  Future<void> restoreSettings(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? settings = _asStringKeyMap(backup['settings']);
    if (settings == null) {
      throw const FormatException('Backup settings must be a JSON object.');
    }
    _validateAccountSettings(settings);
    await runAccountStorageMutation(() async {
      final Map<String, Object> snapshot = _captureAccountSettings();
      try {
        await _replaceAccountSettings(settings);
      } on Object catch (restoreError, restoreStack) {
        try {
          await _replaceAccountSettings(snapshot);
        } on Object catch (rollbackError) {
          throw BackupRestoreRollbackException(
            restoreErrorType: restoreError.runtimeType.toString(),
            rollbackErrorType: rollbackError.runtimeType.toString(),
          );
        }
        Error.throwWithStackTrace(restoreError, restoreStack);
      }
    }, coordinator: _mutationCoordinator);
  }

  Map<String, dynamic>? _decodeProfile(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return _asStringKeyMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<String?> _readProfile() async {
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      final String? secured = await secure.readString(_secureProfileStateKey);
      if (secured != null) return secured;
    }
    await profileStorage.open();
    final String? legacy = profileStorage.get(_profileStateKey);
    if (legacy != null && secure != null) {
      await secure.writeString(_secureProfileStateKey, legacy);
      await profileStorage.delete(_profileStateKey);
    }
    return legacy;
  }

  Future<void> _writeProfile(String value) async {
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      await secure.writeString(_secureProfileStateKey, value);
      await profileStorage.delete(_profileStateKey);
      return;
    }
    await profileStorage.put(_profileStateKey, value);
  }

  Future<void> _deleteProfile() async {
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      await secure.delete(_secureProfileStateKey);
    }
    await profileStorage.delete(_profileStateKey);
  }

  Future<_RestoreSnapshot> _captureRestoreSnapshot() async {
    await profileStorage.open();
    final String? legacyProfile = profileStorage.get(_profileStateKey);
    final String? secureProfile = await secureProfileStore?.readString(
      _secureProfileStateKey,
    );
    return _RestoreSnapshot(
      tasks: await taskRepository.getAllTasks(),
      goals: _readGoalsForBackup(),
      habits: await habitRepository!.getHabits(),
      notes: await _readNotesForBackup(),
      taskOccurrences: await taskOccurrenceRepository!.listOccurrences(),
      habitOccurrences: await habitOccurrenceRepository!.load(),
      decisionOutcomes: await decisionOutcomeRepository!.load(),
      secureProfilePresent: secureProfile != null,
      secureProfile: secureProfile,
      legacyProfilePresent: legacyProfile != null,
      legacyProfile: legacyProfile,
      settings: _captureAccountSettings(),
    );
  }

  Future<_LegacyRestoreSnapshot> _captureLegacyRestoreSnapshot() async {
    await profileStorage.open();
    final String? legacyProfile = profileStorage.get(_profileStateKey);
    final String? secureProfile = await secureProfileStore?.readString(
      _secureProfileStateKey,
    );
    return _LegacyRestoreSnapshot(
      tasks: await taskRepository.getAllTasks(),
      secureProfilePresent: secureProfile != null,
      secureProfile: secureProfile,
      legacyProfilePresent: legacyProfile != null,
      legacyProfile: legacyProfile,
      settings: _captureAccountSettings(),
    );
  }

  Future<void> _restoreLegacySnapshot(_LegacyRestoreSnapshot snapshot) async {
    final List<Object> failures = <Object>[];
    for (final Future<void> Function() restoreDomain
        in <Future<void> Function()>[
          () => _replaceTasks(snapshot.tasks),
          () => _restoreLegacyProfileSnapshot(snapshot),
          () => _replaceAccountSettings(snapshot.settings),
        ]) {
      try {
        await restoreDomain();
      } on Object catch (error) {
        failures.add(error);
      }
    }
    if (failures.isNotEmpty) throw failures.first;
  }

  Future<void> _restoreLegacyProfileSnapshot(
    _LegacyRestoreSnapshot snapshot,
  ) async {
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      if (snapshot.secureProfilePresent && snapshot.secureProfile != null) {
        await secure.writeString(
          _secureProfileStateKey,
          snapshot.secureProfile!,
        );
      } else {
        await secure.delete(_secureProfileStateKey);
      }
    }
    if (snapshot.legacyProfilePresent && snapshot.legacyProfile != null) {
      await profileStorage.put(_profileStateKey, snapshot.legacyProfile!);
    } else {
      await profileStorage.delete(_profileStateKey);
    }
  }

  Future<void> _restoreSnapshot(_RestoreSnapshot snapshot) async {
    final List<Object> failures = <Object>[];
    for (final Future<void> Function() restoreDomain
        in <Future<void> Function()>[
          () => _replaceTasks(snapshot.tasks),
          () => goalRepository!.saveGoals(snapshot.goals),
          () => habitRepository!.saveHabits(snapshot.habits),
          () => _replaceNotes(snapshot.notes),
          () => taskOccurrenceRepository!.replaceSnapshot(
            snapshot.taskOccurrences,
          ),
          () => habitOccurrenceRepository!.replaceSnapshot(
            snapshot.habitOccurrences,
          ),
          () => _replaceDecisionOutcomes(snapshot.decisionOutcomes),
          () => _restoreProfileSnapshot(snapshot),
          () => _restoreSettingSnapshot(snapshot),
        ]) {
      try {
        await restoreDomain();
      } on Object catch (error) {
        failures.add(error);
      }
    }
    if (failures.isNotEmpty) {
      throw failures.first;
    }
  }

  Future<void> _restoreProfileSnapshot(_RestoreSnapshot snapshot) async {
    final List<Object> failures = <Object>[];
    final SecureStore? secure = secureProfileStore;
    if (secure != null) {
      try {
        if (snapshot.secureProfilePresent && snapshot.secureProfile != null) {
          await secure.writeString(
            _secureProfileStateKey,
            snapshot.secureProfile!,
          );
        } else {
          await secure.delete(_secureProfileStateKey);
        }
      } on Object catch (error) {
        failures.add(error);
      }
    }
    try {
      if (snapshot.legacyProfilePresent && snapshot.legacyProfile != null) {
        await profileStorage.put(_profileStateKey, snapshot.legacyProfile!);
      } else {
        await profileStorage.delete(_profileStateKey);
      }
    } on Object catch (error) {
      failures.add(error);
    }
    if (failures.isNotEmpty) {
      throw failures.first;
    }
  }

  Future<void> _restoreSettingSnapshot(_RestoreSnapshot snapshot) async {
    await _replaceAccountSettings(snapshot.settings);
  }

  Map<String, dynamic> _readAccountSettings() {
    final Map<String, dynamic> settings = <String, dynamic>{};
    for (final String key in _sortedAccountSettingKeys) {
      final Object? value = prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }
    _validateAccountSettings(settings);
    return settings;
  }

  Map<String, Object> _captureAccountSettings() {
    final Map<String, Object> snapshot = <String, Object>{};
    for (final String key in _sortedAccountSettingKeys) {
      final Object? value = prefs.get(key);
      if (value != null) {
        snapshot[key] = value;
      }
    }
    return snapshot;
  }

  List<String> get _sortedAccountSettingKeys {
    return AccountDataRegistry.accountPreferenceBackupKeys.toList()..sort();
  }

  Future<void> _replaceAccountSettings(
    Map<String, dynamic> settings, {
    bool Function()? canContinue,
  }) async {
    for (final String key in _sortedAccountSettingKeys) {
      _requireRestoreLease(canContinue);
      await prefs.remove(key);
    }
    for (final String key in _sortedAccountSettingKeys) {
      if (!settings.containsKey(key)) continue;
      _requireRestoreLease(canContinue);
      await _writePreferenceValue(key, settings[key]);
    }
  }

  Future<void> _writePreferenceValue(String key, Object? value) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      throw StateError('Existing preference $key could not be restored.');
    }
  }

  Future<void> _replaceTasks(
    List<TaskEntity> tasks, {
    bool Function()? canContinue,
  }) async {
    _requireRestoreLease(canContinue);
    final ITaskRepository repository = taskRepository;
    if (repository is IExactTaskSnapshotRepository) {
      await (repository as IExactTaskSnapshotRepository).replaceTaskSnapshot(
        tasks,
      );
      _requireRestoreLease(canContinue);
      return;
    }
    final List<TaskEntity> current = await taskRepository.getAllTasks();
    for (final TaskEntity task in current) {
      _requireRestoreLease(canContinue);
      await taskRepository.deleteTask(task.id);
    }
    for (final TaskEntity task in tasks) {
      _requireRestoreLease(canContinue);
      await taskRepository.saveTask(task);
    }
    _requireRestoreLease(canContinue);
  }

  Future<void> _replaceNotes(List<NoteEntity> notes) async {
    final INoteRepository repository = noteRepository!;
    if (repository is IExactNoteSnapshotRepository) {
      await (repository as IExactNoteSnapshotRepository).replaceNoteSnapshot(
        notes,
      );
      return;
    }
    final List<NoteEntity> current = await repository.getNotes();
    for (final NoteEntity note in current) {
      await repository.deleteNote(note.id);
    }
    for (final NoteEntity note in notes) {
      await repository.saveNote(note);
    }
  }

  List<GoalEntity> _readGoalsForBackup() {
    final IGoalRepository repository = goalRepository!;
    final List<GoalEntity> goals = repository.getGoals();
    if (repository is GoalRepository && repository.lastReadCorrupted) {
      throw StateError(
        'Portable local backup stopped because Goals storage is unreadable.',
      );
    }
    return goals;
  }

  Future<List<NoteEntity>> _readNotesForBackup() async {
    final INoteRepository repository = noteRepository!;
    final List<NoteEntity> notes = await repository.getNotes();
    if (repository is NoteRepository && repository.lastReadCorrupted) {
      throw StateError(
        'Portable local backup stopped because Notes storage is unreadable.',
      );
    }
    return notes;
  }

  Future<void> _replaceDecisionOutcomes(
    List<DecisionOutcomeEntity> outcomes,
  ) async {
    final IDecisionOutcomeRepository repository = decisionOutcomeRepository!;
    if (repository is! IExactDecisionOutcomeSnapshotRepository) {
      throw StateError(
        'Decision outcome repository cannot replace an exact snapshot.',
      );
    }
    await (repository as IExactDecisionOutcomeSnapshotRepository)
        .replaceSnapshot(outcomes);
  }

  void _requireCompleteLocalContinuity() {
    final AccountStorageScope? activeScope = scope;
    if (activeScope == null || !activeScope.isWritable) {
      throw StateError(
        'Portable local backup requires authenticated account storage.',
      );
    }
    if (goalRepository == null ||
        habitRepository == null ||
        noteRepository == null ||
        taskOccurrenceRepository == null ||
        habitOccurrenceRepository == null ||
        decisionOutcomeRepository == null) {
      throw StateError(
        'Portable local backup is unavailable because a canonical domain repository is missing.',
      );
    }
  }

  Map<String, dynamic> _accountEnvelope() {
    final AccountStorageScope activeScope = scope!;
    return <String, dynamic>{
      'namespace': activeScope.v2Namespace,
      'accountDigest': AccountDataRegistry.accountDigest(
        activeScope.rawUserId!,
      ),
    };
  }

  void _requireRestoreLease(bool Function()? canContinue) {
    if (canContinue != null && !canContinue()) {
      throw const BackupRestoreCancelledException();
    }
  }

  Map<String, dynamic>? _profileFromLegacyUser(dynamic rawUser) {
    final Map<String, dynamic>? user = _asStringKeyMap(rawUser);
    final String name = user?['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      'xp': 0,
      'level': 1,
      'streak': 0,
      'longestStreak': 0,
      'name': name,
      'soundEnabled': true,
      'lastActiveDate': null,
    };
  }

  _ValidatedFullBackup _validateFullBackup(Map<String, dynamic> backup) {
    final String version = backup['version'] is String
        ? (backup['version'] as String).trim()
        : '';
    if (version != _backupVersion && !_legacyBackupVersions.contains(version)) {
      throw const FormatException('Unsupported full-backup version.');
    }
    final String timestamp = backup['timestamp'] is String
        ? (backup['timestamp'] as String).trim()
        : '';
    final DateTime? createdAt = DateTime.tryParse(timestamp);
    if (timestamp.isEmpty || createdAt == null) {
      throw const FormatException('Full backup timestamp is invalid.');
    }
    _validateManifest(backup['manifest'], version: version);
    final bool isCurrent = version == _backupVersion;
    final List<String> requiredKeys = <String>[
      'tasks',
      'profile',
      'settings',
      if (isCurrent) ...<String>[
        'account',
        'goals',
        'habits',
        'notes',
        'taskOccurrences',
        'habitOccurrences',
        'decisionOutcomes',
        'recordCounts',
      ],
    ];
    for (final String requiredKey in requiredKeys) {
      if (!backup.containsKey(requiredKey)) {
        throw FormatException('Full backup is missing $requiredKey.');
      }
    }
    if (isCurrent) _validateAccountEnvelope(backup['account']);

    final List<TaskEntity> tasks = _taskEntitiesFromRaw(backup['tasks']);
    final List<GoalEntity> goals = isCurrent
        ? _goalEntitiesFromRaw(backup['goals'])
        : const <GoalEntity>[];
    final List<HabitEntity> habits = isCurrent
        ? _habitEntitiesFromRaw(backup['habits'])
        : const <HabitEntity>[];
    final List<NoteEntity> notes = isCurrent
        ? _noteEntitiesFromRaw(backup['notes'])
        : const <NoteEntity>[];
    final List<TaskOccurrence> taskOccurrences = isCurrent
        ? _taskOccurrencesFromRaw(backup['taskOccurrences'])
        : const <TaskOccurrence>[];
    final List<HabitOccurrenceEntity> habitOccurrences = isCurrent
        ? _habitOccurrencesFromRaw(backup['habitOccurrences'])
        : const <HabitOccurrenceEntity>[];
    final List<DecisionOutcomeEntity> decisionOutcomes = isCurrent
        ? _decisionOutcomesFromRaw(backup['decisionOutcomes'])
        : const <DecisionOutcomeEntity>[];
    final Object? rawProfile = backup['profile'];
    final Map<String, dynamic>? profile = rawProfile == null
        ? null
        : _strictStringKeyMap(rawProfile, field: 'profile');
    final Map<String, dynamic> settings = _strictStringKeyMap(
      backup['settings'],
      field: 'settings',
    );
    _validateJsonValue(profile, field: 'profile');
    _validateJsonValue(settings, field: 'settings');
    _validateAccountSettings(settings);
    final Map<String, int> recordCounts = _recordCounts(
      taskCount: tasks.length,
      goalCount: goals.length,
      habitCount: habits.length,
      noteCount: notes.length,
      taskOccurrenceCount: taskOccurrences.length,
      habitOccurrenceCount: habitOccurrences.length,
      decisionOutcomeCount: decisionOutcomes.length,
      profile: profile,
      settings: settings,
    );
    if (isCurrent) {
      _validateRecordCounts(backup['recordCounts'], expected: recordCounts);
    } else {
      recordCounts.removeWhere(
        (String key, int _) =>
            key != 'tasks' && key != 'profile' && key != 'settings',
      );
    }
    return _ValidatedFullBackup(
      version: version,
      createdAt: createdAt,
      recordCounts: recordCounts,
      tasks: tasks,
      goals: goals,
      habits: habits,
      notes: notes,
      taskOccurrences: taskOccurrences,
      habitOccurrences: habitOccurrences,
      decisionOutcomes: decisionOutcomes,
      profile: profile,
      settings: settings,
    );
  }

  Map<String, int> _recordCounts({
    required int taskCount,
    required int goalCount,
    required int habitCount,
    required int noteCount,
    required int taskOccurrenceCount,
    required int habitOccurrenceCount,
    required int decisionOutcomeCount,
    required Map<String, dynamic>? profile,
    required Map<String, dynamic> settings,
  }) {
    return <String, int>{
      'tasks': taskCount,
      'goals': goalCount,
      'habits': habitCount,
      'notes': noteCount,
      'task_occurrences': taskOccurrenceCount,
      'habit_occurrences': habitOccurrenceCount,
      'decision_outcomes': decisionOutcomeCount,
      'profile': profile == null ? 0 : 1,
      'settings': settings.length,
    };
  }

  void _validateRecordCounts(
    Object? rawCounts, {
    required Map<String, int> expected,
  }) {
    final Map<String, dynamic> counts = _strictStringKeyMap(
      rawCounts,
      field: 'recordCounts',
    );
    if (counts.length != expected.length ||
        !counts.keys.every(expected.containsKey)) {
      throw const FormatException('Full backup record counts are invalid.');
    }
    for (final MapEntry<String, int> entry in expected.entries) {
      final Object? rawValue = counts[entry.key];
      if (rawValue is! int || rawValue < 0 || rawValue != entry.value) {
        throw FormatException(
          'Full backup record count does not match ${entry.key}.',
        );
      }
    }
  }

  void _validateAccountSettings(Map<String, dynamic> settings) {
    final Set<String> unknownKeys = settings.keys.toSet().difference(
      AccountDataRegistry.accountPreferenceBackupKeys,
    );
    if (unknownKeys.isNotEmpty) {
      throw const FormatException(
        'Backup settings contain unsupported account preferences.',
      );
    }

    for (final MapEntry<String, dynamic> entry in settings.entries) {
      final Object? value = entry.value;
      switch (entry.key) {
        case 'user_preferences_json':
          if (value is! String || value.length > 100000) {
            throw const FormatException('Backup user preferences are invalid.');
          }
          try {
            final Object? decoded = jsonDecode(value);
            if (decoded is! Map) {
              throw const FormatException(
                'Backup user preferences are invalid.',
              );
            }
          } on FormatException {
            throw const FormatException('Backup user preferences are invalid.');
          }
          break;
        case 'cloud_sync_enabled_v1':
          if (value is! bool) {
            throw const FormatException(
              'Backup cloud sync preference is invalid.',
            );
          }
          break;
        case 'reflection_reminder_enabled':
        case 'goal_reminders_enabled':
        case 'habit_reminders_enabled':
        case 'daily_planning_reminder_enabled':
          if (value != 'true' && value != 'false') {
            throw FormatException('Backup ${entry.key} preference is invalid.');
          }
          break;
        case 'reflection_reminder_time':
        case 'daily_planning_reminder_time':
          if (value is! String || !_isValidReminderTime(value)) {
            throw FormatException('Backup ${entry.key} preference is invalid.');
          }
          break;
      }
    }
  }

  bool _isValidReminderTime(String value) {
    final List<String> parts = value.split(':');
    if (parts.length != 2) return false;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  List<String> _strictStringList(Object? value, {required String field}) {
    if (value is! List || value.any((Object? item) => item is! String)) {
      throw FormatException('Backup $field must be a string list.');
    }
    return value.cast<String>();
  }

  void _validateManifest(Object? rawManifest, {required String version}) {
    final Map<String, dynamic> manifest = _strictStringKeyMap(
      rawManifest,
      field: 'manifest',
    );
    final bool isCurrent = version == _backupVersion;
    if ((!isCurrent &&
            manifest['manifestVersion'] != 1 &&
            manifest['manifestVersion'] != 2) ||
        (isCurrent && manifest['manifestVersion'] != 2)) {
      throw const FormatException('Unsupported backup manifest version.');
    }
    if (isCurrent &&
        (manifest['backupKind'] != 'portableLocal' ||
            manifest['cloudRestoreIncluded'] != false)) {
      throw const FormatException(
        'Backup manifest does not describe a contained portable local backup.',
      );
    }
    if (!isCurrent) {
      for (final String key in <String>[
        'includedDomains',
        'cloudReplicatedDomains',
        'excludedDomains',
      ]) {
        _strictUniqueStringSet(manifest[key], field: 'manifest.$key');
      }
      if (manifest['domains'] is! List) {
        throw const FormatException('Backup manifest domains are invalid.');
      }
      return;
    }
    final Map<String, dynamic> expected = accountDataBackupManifest();
    for (final String key in <String>[
      'includedDomains',
      'cloudReplicatedDomains',
      'excludedDomains',
    ]) {
      final Set<String> actualValues = _strictUniqueStringSet(
        manifest[key],
        field: 'manifest.$key',
      );
      final Set<String> expectedValues = (expected[key] as List<dynamic>)
          .cast<String>()
          .toSet();
      if (!_sameSet(actualValues, expectedValues)) {
        throw FormatException('Backup manifest $key does not match this app.');
      }
    }

    final Object? rawDomains = manifest['domains'];
    if (rawDomains is! List) {
      throw const FormatException('Backup manifest domains are invalid.');
    }
    final Map<String, String> actualStatuses = <String, String>{};
    for (final Object? rawDomain in rawDomains) {
      final Map<String, dynamic> domain = _strictStringKeyMap(
        rawDomain,
        field: 'manifest.domains',
      );
      final String id = domain['id'] is String
          ? (domain['id'] as String).trim()
          : '';
      final String status = domain['backupStatus'] is String
          ? (domain['backupStatus'] as String).trim()
          : '';
      if (id.isEmpty || status.isEmpty || actualStatuses.containsKey(id)) {
        throw const FormatException('Backup manifest domain is invalid.');
      }
      actualStatuses[id] = status;
    }
    final Map<String, String> expectedStatuses = <String, String>{
      for (final AccountDataDomain domain in accountDataDomains)
        domain.id: domain.backupStatus.name,
    };
    if (!_sameSet(actualStatuses.keys.toSet(), expectedStatuses.keys.toSet())) {
      throw const FormatException(
        'Backup manifest domain inventory does not match this app.',
      );
    }
    for (final MapEntry<String, String> entry in expectedStatuses.entries) {
      if (actualStatuses[entry.key] != entry.value) {
        throw const FormatException(
          'Backup manifest domain status does not match this app.',
        );
      }
    }
  }

  void _validateAccountEnvelope(Object? rawAccount) {
    _requireCompleteLocalContinuity();
    final Map<String, dynamic> account = _strictStringKeyMap(
      rawAccount,
      field: 'account',
    );
    if (account.length != 2 ||
        account['namespace'] != scope!.v2Namespace ||
        account['accountDigest'] !=
            AccountDataRegistry.accountDigest(scope!.rawUserId!)) {
      throw const FormatException(
        'Backup account owner does not match the active account.',
      );
    }
  }

  List<GoalEntity> _goalEntitiesFromRaw(Object? raw) {
    final List<Map<String, dynamic>> values = _strictRecordList(
      raw,
      field: 'goals',
    );
    final List<GoalEntity> goals = <GoalEntity>[];
    final Set<String> ids = <String>{};
    for (final Map<String, dynamic> value in values) {
      _requireNonEmptyString(value, 'id', field: 'goal');
      _requireNonEmptyString(value, 'title', field: 'goal');
      _requireValidDate(value, 'createdAt', required: true, field: 'goal');
      _requireValidDate(value, 'targetDate', field: 'goal');
      _requireValidDate(value, 'completedAt', field: 'goal');
      if (value['colorHex'] is! int) {
        throw const FormatException('Backup goal color is invalid.');
      }
      try {
        final GoalEntity goal = GoalEntity.fromJson(value);
        goal.validate();
        if (!ids.add(goal.id)) {
          throw const FormatException('Backup contains duplicate goal IDs.');
        }
        goals.add(goal);
      } on FormatException {
        rethrow;
      } on Object {
        throw const FormatException('Backup contains a malformed goal.');
      }
    }
    return goals;
  }

  List<HabitEntity> _habitEntitiesFromRaw(Object? raw) {
    final List<Map<String, dynamic>> values = _strictRecordList(
      raw,
      field: 'habits',
    );
    final List<HabitEntity> habits = <HabitEntity>[];
    final Set<String> ids = <String>{};
    for (final Map<String, dynamic> value in values) {
      _requireNonEmptyString(value, 'id', field: 'habit');
      _requireNonEmptyString(value, 'title', field: 'habit');
      _requireValidDate(value, 'createdAt', required: true, field: 'habit');
      _requireValidDate(value, 'updatedAt', required: true, field: 'habit');
      if (!HabitCadence.values.any(
            (HabitCadence cadence) => cadence.name == value['cadence'],
          ) ||
          !HabitStatus.values.any(
            (HabitStatus status) => status.name == value['status'],
          ) ||
          value['targetCount'] is! int ||
          (value['targetCount'] as int) < 1 ||
          value['stepTaskIds'] is! List<dynamic> ||
          (value['stepTaskIds'] as List<dynamic>).any(
            (Object? item) => item is! String,
          )) {
        throw const FormatException('Backup habit fields are invalid.');
      }
      final HabitEntity habit = HabitEntity.fromJson(value);
      if (!ids.add(habit.id)) {
        throw const FormatException('Backup contains duplicate habit IDs.');
      }
      habits.add(habit);
    }
    return habits;
  }

  List<NoteEntity> _noteEntitiesFromRaw(Object? raw) {
    final List<Map<String, dynamic>> values = _strictRecordList(
      raw,
      field: 'notes',
    );
    final List<NoteEntity> notes = <NoteEntity>[];
    final Set<String> ids = <String>{};
    for (final Map<String, dynamic> value in values) {
      _requireNonEmptyString(value, 'id', field: 'note');
      _requireNonEmptyString(value, 'title', field: 'note');
      _requireValidDate(value, 'createdAt', required: true, field: 'note');
      _requireValidDate(value, 'updatedAt', required: true, field: 'note');
      if (value['isArchived'] is! bool) {
        throw const FormatException('Backup note archive state is invalid.');
      }
      for (final String key in <String>[
        'body',
        'userId',
        'goalId',
        'taskId',
        'habitId',
        'occurrenceId',
        'outcomeId',
      ]) {
        if (value[key] != null && value[key] is! String) {
          throw FormatException('Backup note $key is invalid.');
        }
      }
      if (!NoteKind.values.any((NoteKind kind) => kind.name == value['kind'])) {
        throw const FormatException('Backup note kind is invalid.');
      }
      final NoteEntity note = NoteEntity.fromJson(value);
      if (!ids.add(note.id)) {
        throw const FormatException('Backup contains duplicate note IDs.');
      }
      notes.add(note);
    }
    return notes;
  }

  List<TaskOccurrence> _taskOccurrencesFromRaw(Object? raw) {
    final List<Map<String, dynamic>> values = _strictRecordList(
      raw,
      field: 'taskOccurrences',
    );
    final List<TaskOccurrence> occurrences = <TaskOccurrence>[];
    final Set<String> ids = <String>{};
    for (final Map<String, dynamic> value in values) {
      if (value['initialScheduledFor'] != null) {
        _requireValidDate(value, 'initialScheduledFor', field: 'occurrence');
      }
      if (value['pendingOperation'] != null &&
          value['pendingOperation'] is! Map<dynamic, dynamic>) {
        throw const FormatException(
          'Backup task occurrence pending operation is invalid.',
        );
      }
      final TaskOccurrence occurrence = TaskOccurrence.fromJson(value);
      if (!ids.add(occurrence.id)) {
        throw const FormatException(
          'Backup contains duplicate task occurrence IDs.',
        );
      }
      occurrences.add(occurrence);
    }
    return occurrences;
  }

  List<HabitOccurrenceEntity> _habitOccurrencesFromRaw(Object? raw) {
    final List<Map<String, dynamic>> values = _strictRecordList(
      raw,
      field: 'habitOccurrences',
    );
    final List<HabitOccurrenceEntity> occurrences = <HabitOccurrenceEntity>[];
    final Set<String> ids = <String>{};
    for (final Map<String, dynamic> value in values) {
      _requireNonEmptyString(value, 'habitId', field: 'habit occurrence');
      _requireNonEmptyString(value, 'occurrenceKey', field: 'habit occurrence');
      _requireNonEmptyString(value, 'operationId', field: 'habit occurrence');
      _requireValidDate(
        value,
        'recordedAt',
        required: true,
        field: 'habit occurrence',
      );
      if (!HabitOccurrenceOutcome.values.any(
        (HabitOccurrenceOutcome outcome) => outcome.name == value['outcome'],
      )) {
        throw const FormatException(
          'Backup Daily Rhythm occurrence outcome is invalid.',
        );
      }
      final HabitOccurrenceEntity occurrence = HabitOccurrenceEntity.fromJson(
        value,
      );
      if (!ids.add(occurrence.id)) {
        throw const FormatException(
          'Backup contains duplicate Daily Rhythm occurrence slots.',
        );
      }
      occurrences.add(occurrence);
    }
    return occurrences;
  }

  List<DecisionOutcomeEntity> _decisionOutcomesFromRaw(Object? raw) {
    final List<Map<String, dynamic>> values = _strictRecordList(
      raw,
      field: 'decisionOutcomes',
    );
    final List<DecisionOutcomeEntity> outcomes = <DecisionOutcomeEntity>[];
    final Set<String> ids = <String>{};
    for (final Map<String, dynamic> value in values) {
      _requireNonEmptyString(value, 'decisionId', field: 'decision outcome');
      _requireNonEmptyString(value, 'surface', field: 'decision outcome');
      _requireNonEmptyString(value, 'modelVersion', field: 'decision outcome');
      _requireValidDate(
        value,
        'recordedAt',
        required: true,
        field: 'decision outcome',
      );
      final Object? confidence = value['recommendationConfidence'];
      for (final String key in <String>['subjectId', 'detail']) {
        if (value[key] != null && value[key] is! String) {
          throw FormatException('Backup decision outcome $key is invalid.');
        }
      }
      if (!DecisionOutcomeKind.values.any(
            (DecisionOutcomeKind kind) => kind.name == value['kind'],
          ) ||
          confidence is! num ||
          !confidence.isFinite ||
          confidence < 0 ||
          confidence > 1) {
        throw const FormatException('Backup decision outcome is invalid.');
      }
      final DecisionOutcomeEntity outcome = DecisionOutcomeEntity.fromJson(
        value,
      );
      if (!ids.add(outcome.id)) {
        throw const FormatException(
          'Backup contains duplicate decision outcome IDs.',
        );
      }
      outcomes.add(outcome);
    }
    return outcomes;
  }

  List<Map<String, dynamic>> _strictRecordList(
    Object? raw, {
    required String field,
  }) {
    if (raw is! List<dynamic> || raw.length > _maxDomainRecords) {
      throw FormatException('Backup $field must be a bounded JSON list.');
    }
    return raw
        .map((Object? value) => _strictStringKeyMap(value, field: field))
        .toList(growable: false);
  }

  void _requireNonEmptyString(
    Map<String, dynamic> value,
    String key, {
    required String field,
  }) {
    final Object? raw = value[key];
    if (raw is! String || raw.trim().isEmpty || raw != raw.trim()) {
      throw FormatException('Backup $field $key is invalid.');
    }
  }

  List<TaskEntity> _taskEntitiesFromRaw(dynamic rawTasks) {
    if (rawTasks is! List) {
      throw const FormatException('Backup tasks must be a JSON list.');
    }
    if (rawTasks.length > _maxTaskRecords) {
      throw const FormatException('Backup contains too many task records.');
    }

    final List<TaskEntity> tasks = <TaskEntity>[];
    final Set<String> taskIds = <String>{};
    for (final Object? rawTask in rawTasks) {
      try {
        final Map<String, dynamic> item = _strictStringKeyMap(
          rawTask,
          field: 'tasks',
        );
        _validateTaskJson(item);
        final TaskEntity task = TaskEntityMapper.fromJson(item);
        task.validate();
        if (!taskIds.add(task.id)) {
          throw const FormatException('Backup contains duplicate task IDs.');
        }
        tasks.add(task);
      } on FormatException {
        rethrow;
      } on Object {
        throw const FormatException('Backup contains a malformed task record.');
      }
    }
    return tasks;
  }

  void _validateTaskJson(Map<String, dynamic> task) {
    final String id = task['id'] is String ? (task['id'] as String).trim() : '';
    final String title = task['title'] is String
        ? (task['title'] as String).trim()
        : '';
    if (id.isEmpty || id.length > _maxTaskIdLength) {
      throw const FormatException('Backup task ID is invalid.');
    }
    if (title.isEmpty || title.length > _maxTaskTitleLength) {
      throw const FormatException('Backup task title is invalid.');
    }
    _requireValidDate(task, 'createdAt', required: true);
    for (final String key in <String>[
      'updatedAt',
      'completedAt',
      'skippedAt',
      'scheduledFor',
      'dueDate',
    ]) {
      _requireValidDate(task, key);
    }
    for (final String key in <String>[
      'isCompleted',
      'isSkipped',
      'isCanceled',
    ]) {
      final Object? value = task[key];
      if (value != null && value is! bool) {
        throw FormatException('Backup task $key is invalid.');
      }
    }
    for (final String key in <String>[
      'priority',
      'difficulty',
      'energyRequired',
      'estimatedDurationMs',
    ]) {
      final Object? value = task[key];
      if (value != null && (value is! int || value < 0)) {
        throw FormatException('Backup task $key is invalid.');
      }
    }
    for (final String key in <String>[
      'description',
      'occurrenceKey',
      'goalId',
    ]) {
      final Object? value = task[key];
      if (value != null && value is! String) {
        throw FormatException('Backup task $key is invalid.');
      }
    }
    final String? description = task['description'] as String?;
    if (description != null && description.length > _maxTaskDescriptionLength) {
      throw const FormatException('Backup task description is too long.');
    }
    final Object? rawSubtasks = task['subtasks'];
    if (rawSubtasks != null &&
        (rawSubtasks is! List ||
            rawSubtasks.length > _maxSubtasksPerTask ||
            rawSubtasks.any((Object? value) => value is! String))) {
      throw const FormatException('Backup task subtasks are invalid.');
    }
    final Object? recurrence = task['recurrenceRule'];
    if (recurrence != null &&
        (recurrence is! String ||
            !RecurrenceRule.values.any(
              (RecurrenceRule value) => value.name == recurrence,
            ))) {
      throw const FormatException('Backup task recurrence is invalid.');
    }
  }

  void _requireValidDate(
    Map<String, dynamic> task,
    String key, {
    bool required = false,
    String field = 'task',
  }) {
    final Object? value = task[key];
    if (value == null && !required) return;
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('Backup $field $key is invalid.');
    }
  }

  Map<String, dynamic> _strictStringKeyMap(
    Object? value, {
    required String field,
  }) {
    if (value is! Map || value.keys.any((Object? key) => key is! String)) {
      throw FormatException('Backup $field must be a JSON object.');
    }
    return value.cast<String, dynamic>();
  }

  Set<String> _strictUniqueStringSet(Object? value, {required String field}) {
    if (value is! List || value.any((Object? item) => item is! String)) {
      throw FormatException('Backup $field must be a string list.');
    }
    final List<String> values = value.cast<String>();
    final Set<String> unique = values.toSet();
    if (unique.length != values.length ||
        unique.any((String item) => item.trim().isEmpty)) {
      throw FormatException('Backup $field contains invalid values.');
    }
    return unique;
  }

  bool _sameSet(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  void _validateJsonValue(
    Object? value, {
    required String field,
    int depth = 0,
  }) {
    if (depth > 50) {
      throw FormatException('Backup $field is nested too deeply.');
    }
    if (value == null || value is String || value is bool) return;
    if (value is num) {
      if (!value.isFinite) {
        throw FormatException('Backup $field contains a non-finite number.');
      }
      return;
    }
    if (value is List) {
      for (final Object? item in value) {
        _validateJsonValue(item, field: field, depth: depth + 1);
      }
      return;
    }
    if (value is Map && value.keys.every((Object? key) => key is String)) {
      for (final Object? item in value.values) {
        _validateJsonValue(item, field: field, depth: depth + 1);
      }
      return;
    }
    throw FormatException('Backup $field contains a non-JSON value.');
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) {
      return null;
    }
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
}
