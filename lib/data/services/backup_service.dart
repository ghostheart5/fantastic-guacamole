import 'dart:convert';

import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
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

class _ValidatedFullBackup {
  const _ValidatedFullBackup({
    required this.tasks,
    required this.profile,
    required this.settings,
  });

  final List<TaskEntity> tasks;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic> settings;
}

class _RestoreSnapshot {
  const _RestoreSnapshot({
    required this.tasks,
    required this.secureProfilePresent,
    required this.secureProfile,
    required this.legacyProfilePresent,
    required this.legacyProfile,
    required this.settingsPresent,
    required this.settings,
  });

  final List<TaskEntity> tasks;
  final bool secureProfilePresent;
  final String? secureProfile;
  final bool legacyProfilePresent;
  final String? legacyProfile;
  final bool settingsPresent;
  final Object? settings;
}

class BackupService {
  BackupService({
    required this.taskRepository,
    required this.profileStorage,
    required this.prefs,
    this.secureProfileStore,
  });

  static const String _profileStateKey = 'profile_state';
  static const String _backupVersion = '3.0.0';
  static const int _maxTaskRecords = 10000;
  static const int _maxTaskIdLength = 256;
  static const int _maxTaskTitleLength = 4096;
  static const int _maxTaskDescriptionLength = 100000;
  static const int _maxSubtasksPerTask = 1000;

  final ITaskRepository taskRepository;
  final HiveStorage<String> profileStorage;
  final SharedPrefsStorage prefs;
  final SecureStore? secureProfileStore;
  static const String _secureProfileStateKey = 'profile_state_v2';

  Future<Map<String, dynamic>> createFullBackup() async {
    final List<TaskEntity> tasks = await taskRepository.getAllTasks();
    final Map<String, dynamic>? profile = _decodeProfile(await _readProfile());
    final Map<String, dynamic> settings = prefs.getJson('settings');

    return <String, dynamic>{
      'version': _backupVersion,
      'manifest': accountDataBackupManifest(),
      'timestamp': DateTime.now().toIso8601String(),
      'tasks': tasks.map(TaskEntityMapper.toJson).toList(),
      'profile': profile,
      'settings': settings,
    };
  }

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
      'settings': prefs.getJson('settings'),
    };
  }

  Future<String> exportFullBackupString() async {
    return jsonEncode(await createFullBackup());
  }

  Future<String> exportTasksString() async {
    return jsonEncode(await backupTasks());
  }

  Future<void> restoreFullBackup(Map<String, dynamic> backup) async {
    final _ValidatedFullBackup validated = _validateFullBackup(backup);
    final _RestoreSnapshot snapshot = await _captureRestoreSnapshot();

    try {
      await _replaceTasks(validated.tasks);
      if (validated.profile == null) {
        await _deleteProfile();
      } else {
        await _writeProfile(jsonEncode(validated.profile));
      }
      await prefs.setJson('settings', validated.settings);
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

  Future<void> restoreTasks(Map<String, dynamic> backup) async {
    final List<TaskEntity> restoredTasks = _taskEntitiesFromRaw(
      backup['tasks'],
    );
    final List<TaskEntity> existing = await taskRepository.getAllTasks();
    try {
      await _replaceTasks(restoredTasks);
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
    await _writeProfile(jsonEncode(profile));
  }

  Future<void> restoreSettings(Map<String, dynamic> backup) async {
    final Map<String, dynamic>? settings = _asStringKeyMap(backup['settings']);
    if (settings == null) {
      throw const FormatException('Backup settings must be a JSON object.');
    }
    await prefs.setJson('settings', settings);
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
      secureProfilePresent: secureProfile != null,
      secureProfile: secureProfile,
      legacyProfilePresent: legacyProfile != null,
      legacyProfile: legacyProfile,
      settingsPresent: prefs.contains('settings'),
      settings: prefs.prefs.get('settings'),
    );
  }

  Future<void> _restoreSnapshot(_RestoreSnapshot snapshot) async {
    final List<Object> failures = <Object>[];
    for (final Future<void> Function() restoreDomain
        in <Future<void> Function()>[
          () => _replaceTasks(snapshot.tasks),
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
    if (!snapshot.settingsPresent) {
      await prefs.remove('settings');
      return;
    }
    final Object? value = snapshot.settings;
    if (value is String) {
      await prefs.setString('settings', value);
    } else if (value is bool) {
      await prefs.setBool('settings', value);
    } else if (value is int) {
      await prefs.setInt('settings', value);
    } else if (value is double) {
      await prefs.setDouble('settings', value);
    } else {
      throw StateError('Existing settings value could not be restored.');
    }
  }

  Future<void> _replaceTasks(List<TaskEntity> tasks) async {
    final List<TaskEntity> current = await taskRepository.getAllTasks();
    for (final TaskEntity task in current) {
      await taskRepository.deleteTask(task.id);
    }
    for (final TaskEntity task in tasks) {
      await taskRepository.saveTask(task);
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
    if (backup['version'] != _backupVersion) {
      throw const FormatException('Unsupported full-backup version.');
    }
    final String timestamp = backup['timestamp'] is String
        ? (backup['timestamp'] as String).trim()
        : '';
    if (timestamp.isEmpty || DateTime.tryParse(timestamp) == null) {
      throw const FormatException('Full backup timestamp is invalid.');
    }
    _validateManifest(backup['manifest']);
    for (final String requiredKey in <String>['tasks', 'profile', 'settings']) {
      if (!backup.containsKey(requiredKey)) {
        throw FormatException('Full backup is missing $requiredKey.');
      }
    }

    final List<TaskEntity> tasks = _taskEntitiesFromRaw(backup['tasks']);
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
    return _ValidatedFullBackup(
      tasks: tasks,
      profile: profile,
      settings: settings,
    );
  }

  void _validateManifest(Object? rawManifest) {
    final Map<String, dynamic> manifest = _strictStringKeyMap(
      rawManifest,
      field: 'manifest',
    );
    if (manifest['manifestVersion'] != 1) {
      throw const FormatException('Unsupported backup manifest version.');
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
  }) {
    final Object? value = task[key];
    if (value == null && !required) return;
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('Backup task $key is invalid.');
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
