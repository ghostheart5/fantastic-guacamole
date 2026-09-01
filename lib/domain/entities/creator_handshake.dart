// CHRONOSPARK-CLASS: SHIPPING | Feature: Creator handshake
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

enum CreatorMutationKind { createTask, createGoal, createHabit, createNote }

enum CreatorEntityKind { task, goal, habit, note }

enum CreatorHandshakeSource { creator, smartPlanner }

enum CreatorHandshakePhase {
  idle,
  preview,
  confirming,
  stale,
  expired,
  applied,
  idempotent,
  conflict,
  undone,
  failed,
}

sealed class CreatorEntityMutation {
  const CreatorEntityMutation();

  CreatorEntityKind get entityKind;
  String get entityId;
  String get title;
  String? get description;
  DateTime get createdAt;
  Map<String, Object?> toCanonicalJson();

  String get digest => creatorHandshakeDigest(toCanonicalJson());
}

final class CreatorTaskMutation extends CreatorEntityMutation {
  const CreatorTaskMutation({
    required this.taskId,
    required this.creatorKind,
    required this.title,
    required this.description,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
    required this.createdAt,
    this.goalId,
    this.estimatedDuration,
    this.dueDate,
    required this.scheduledFor,
    required this.recurrenceRule,
  });

  final String taskId;
  final String creatorKind;
  @override
  final String title;
  @override
  final String? description;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final String? goalId;
  final Duration? estimatedDuration;
  final DateTime? dueDate;
  @override
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final RecurrenceRule recurrenceRule;

  @override
  CreatorEntityKind get entityKind => CreatorEntityKind.task;

  @override
  String get entityId => taskId;

  @override
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'creatorKind': creatorKind,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'description': description,
    'difficulty': difficulty,
    'energyRequired': energyRequired,
    'estimatedDurationMinutes': estimatedDuration?.inMinutes,
    'goalId': goalId,
    'priority': priority,
    'recurrenceRule': recurrenceRule.name,
    'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
    'dueDate': dueDate?.toUtc().toIso8601String(),
    'taskId': taskId,
    'title': title,
  };
}

final class CreatorGoalMutation extends CreatorEntityMutation {
  const CreatorGoalMutation({
    required this.goalId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.targetDate,
    required this.colorHex,
  });

  final String goalId;
  @override
  final String title;
  @override
  final String? description;
  @override
  final DateTime createdAt;
  final DateTime? targetDate;
  final int colorHex;

  @override
  CreatorEntityKind get entityKind => CreatorEntityKind.goal;

  @override
  String get entityId => goalId;

  @override
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'colorHex': colorHex,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'description': description,
    'goalId': goalId,
    'targetDate': targetDate?.toUtc().toIso8601String(),
    'title': title,
  };
}

final class CreatorHabitMutation extends CreatorEntityMutation {
  const CreatorHabitMutation({
    required this.habitId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.cadence,
    required this.targetCount,
  });

  final String habitId;
  @override
  final String title;
  @override
  final String? description;
  @override
  final DateTime createdAt;
  final HabitCadence cadence;
  final int targetCount;

  @override
  CreatorEntityKind get entityKind => CreatorEntityKind.habit;

  @override
  String get entityId => habitId;

  @override
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'cadence': cadence.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'description': description,
    'habitId': habitId,
    'targetCount': targetCount,
    'title': title,
  };
}

final class CreatorNoteMutation extends CreatorEntityMutation {
  const CreatorNoteMutation({
    required this.noteId,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String noteId;
  @override
  final String title;
  final String? body;
  @override
  final DateTime createdAt;

  @override
  CreatorEntityKind get entityKind => CreatorEntityKind.note;

  @override
  String get entityId => noteId;

  @override
  String? get description => body;

  @override
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'noteId': noteId,
    'title': title,
  };
}

final class CreatorMutationOperation {
  const CreatorMutationOperation({
    required this.operationId,
    required this.kind,
    required this.label,
    CreatorEntityMutation? mutation,
    CreatorTaskMutation? task,
    CreatorGoalMutation? goal,
    CreatorHabitMutation? habit,
    CreatorNoteMutation? note,
  }) : assert(
         (mutation != null ? 1 : 0) +
                 (task != null ? 1 : 0) +
                 (goal != null ? 1 : 0) +
                 (habit != null ? 1 : 0) +
                 (note != null ? 1 : 0) ==
             1,
         'Creator operations require exactly one typed mutation.',
       ),
       mutation =
           mutation ??
           task ??
           goal ??
           habit ??
           note ??
           const _MissingCreatorMutation();

  final String operationId;
  final CreatorMutationKind kind;
  final String label;
  final CreatorEntityMutation mutation;

  CreatorEntityKind get entityKind => mutation.entityKind;
  String get entityId => mutation.entityId;
  String get entityDigest => mutation.digest;

  CreatorTaskMutation? get taskMutation => switch (mutation) {
    final CreatorTaskMutation value => value,
    _ => null,
  };

  CreatorGoalMutation? get goal => switch (mutation) {
    final CreatorGoalMutation value => value,
    _ => null,
  };

  CreatorHabitMutation? get habit => switch (mutation) {
    final CreatorHabitMutation value => value,
    _ => null,
  };

  CreatorNoteMutation? get note => switch (mutation) {
    final CreatorNoteMutation value => value,
    _ => null,
  };

  /// Compatibility projection for the current task-focused preview UI.
  /// Persistence and replay always use [mutation], never this projection.
  CreatorTaskMutation get task {
    final CreatorEntityMutation value = mutation;
    if (value is CreatorTaskMutation) return value;
    return CreatorTaskMutation(
      taskId: value.entityId,
      creatorKind: switch (value.entityKind) {
        CreatorEntityKind.task => 'Task',
        CreatorEntityKind.goal => 'Goal',
        CreatorEntityKind.habit => 'Daily Rhythm',
        CreatorEntityKind.note => 'Note',
      },
      title: value.title,
      description: value.description,
      priority: 3,
      difficulty: 3,
      energyRequired: 3,
      createdAt: value.createdAt,
      scheduledFor: value is CreatorGoalMutation ? value.targetDate : null,
      recurrenceRule: value is CreatorHabitMutation
          ? switch (value.cadence) {
              HabitCadence.daily => RecurrenceRule.daily,
              HabitCadence.weekly => RecurrenceRule.weekly,
              HabitCadence.monthly => RecurrenceRule.none,
            }
          : RecurrenceRule.none,
    );
  }

  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'kind': kind.name,
    'label': label,
    'operationId': operationId,
    'mutation': mutation.toCanonicalJson(),
  };
}

final class CreatorPersonContextBinding {
  CreatorPersonContextBinding({
    required this.revision,
    required this.hasBoundEvidence,
    required List<String> evidenceSummary,
  }) : evidenceSummary = List<String>.unmodifiable(evidenceSummary) {
    if (revision.trim().isEmpty) {
      throw ArgumentError('Creator person context revision cannot be blank.');
    }
    if (evidenceSummary.any((String evidence) => evidence.trim().isEmpty) ||
        hasBoundEvidence != evidenceSummary.isNotEmpty) {
      throw ArgumentError(
        'Creator person context binding must match its evidence summary.',
      );
    }
  }

  final String revision;
  final bool hasBoundEvidence;
  final List<String> evidenceSummary;

  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'hasBoundEvidence': hasBoundEvidence,
    'evidenceSummary': evidenceSummary,
    'revision': revision,
  };
}

final class CreatorHandshakePreview {
  CreatorHandshakePreview({
    this.schemaVersion = currentSchemaVersion,
    required this.proposalId,
    required this.accountScopeId,
    required this.source,
    required this.baseDomainRevision,
    required this.createdAt,
    required this.expiresAt,
    required List<CreatorMutationOperation> operations,
    required Set<String> selectedOperationIds,
    this.personContextBinding,
  }) : operations = List<CreatorMutationOperation>.unmodifiable(operations),
       selectedOperationIds = Set<String>.unmodifiable(selectedOperationIds) {
    _validate();
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String proposalId;
  final String accountScopeId;
  final CreatorHandshakeSource source;
  final String baseDomainRevision;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<CreatorMutationOperation> operations;
  final Set<String> selectedOperationIds;
  final CreatorPersonContextBinding? personContextBinding;

  List<CreatorMutationOperation> get selectedOperations => operations
      .where(
        (CreatorMutationOperation operation) =>
            selectedOperationIds.contains(operation.operationId),
      )
      .toList(growable: false);

  String get displayedDiffDigest => creatorHandshakeDigest(<String, Object?>{
    'accountScopeId': accountScopeId,
    'baseDomainRevision': baseDomainRevision,
    'operations': operations
        .map((CreatorMutationOperation item) => item.toCanonicalJson())
        .toList(growable: false),
    'personContextBinding': personContextBinding?.toCanonicalJson(),
    'proposalId': proposalId,
    'schemaVersion': schemaVersion,
    'selectedOperationIds': selectedOperationIds.toList()..sort(),
    'source': source.name,
  });

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt.toUtc());

  CreatorHandshakePreview copyWith({
    String? baseDomainRevision,
    DateTime? createdAt,
    DateTime? expiresAt,
    Set<String>? selectedOperationIds,
    CreatorPersonContextBinding? personContextBinding,
  }) => CreatorHandshakePreview(
    schemaVersion: schemaVersion,
    proposalId: proposalId,
    accountScopeId: accountScopeId,
    source: source,
    baseDomainRevision: baseDomainRevision ?? this.baseDomainRevision,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    operations: operations,
    selectedOperationIds: selectedOperationIds ?? this.selectedOperationIds,
    personContextBinding: personContextBinding ?? this.personContextBinding,
  );

  void _validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw StateError('Unsupported Creator handshake schema version.');
    }
    if (proposalId.trim().isEmpty || accountScopeId.trim().isEmpty) {
      throw ArgumentError('Creator handshake identity cannot be blank.');
    }
    if (operations.isEmpty) {
      throw ArgumentError('Creator handshake requires at least one operation.');
    }
    final Set<String> operationIds = operations
        .map((CreatorMutationOperation item) => item.operationId)
        .toSet();
    if (operationIds.length != operations.length ||
        !operationIds.containsAll(selectedOperationIds)) {
      throw ArgumentError(
        'Selected Creator operations must be unique members of the preview.',
      );
    }
    if (operations.any(
      (CreatorMutationOperation operation) =>
          operation.mutation is _MissingCreatorMutation ||
          operation.kind.entityKind != operation.entityKind,
    )) {
      throw ArgumentError(
        'Creator operation kinds must match their typed mutations.',
      );
    }
    if (!expiresAt.toUtc().isAfter(createdAt.toUtc())) {
      throw ArgumentError('Creator handshake expiry must follow creation.');
    }
  }
}

final class _MissingCreatorMutation extends CreatorEntityMutation {
  const _MissingCreatorMutation();

  @override
  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String? get description => null;

  @override
  String get entityId => '';

  @override
  CreatorEntityKind get entityKind => CreatorEntityKind.task;

  @override
  String get title => '';

  @override
  Map<String, Object?> toCanonicalJson() => const <String, Object?>{};
}

final class CreatorConfirmationToken {
  CreatorConfirmationToken._({
    required this.tokenId,
    required this.proposalId,
    required this.accountScopeId,
    required this.surfaceId,
    required this.baseDomainRevision,
    required this.displayedDiffDigest,
    required this.selectedOperationIds,
    required this.issuedAt,
    required this.expiresAt,
    required this.bindingDigest,
  });

  factory CreatorConfirmationToken.issue({
    required CreatorHandshakePreview preview,
    required DateTime issuedAt,
  }) {
    final List<String> selected = preview.selectedOperationIds.toList()..sort();
    final Map<String, Object?> binding = <String, Object?>{
      'accountScopeId': preview.accountScopeId,
      'baseDomainRevision': preview.baseDomainRevision,
      'displayedDiffDigest': preview.displayedDiffDigest,
      'expiresAt': preview.expiresAt.toUtc().toIso8601String(),
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'personContextBinding': preview.personContextBinding?.toCanonicalJson(),
      'proposalId': preview.proposalId,
      'selectedOperationIds': selected,
      'surfaceId': 'creator',
    };
    final String digest = creatorHandshakeDigest(binding);
    return CreatorConfirmationToken._(
      tokenId: 'creator-confirm-${digest.substring(0, 24)}',
      proposalId: preview.proposalId,
      accountScopeId: preview.accountScopeId,
      surfaceId: 'creator',
      baseDomainRevision: preview.baseDomainRevision,
      displayedDiffDigest: preview.displayedDiffDigest,
      selectedOperationIds: List<String>.unmodifiable(selected),
      issuedAt: issuedAt.toUtc(),
      expiresAt: preview.expiresAt.toUtc(),
      bindingDigest: digest,
    );
  }

  final String tokenId;
  final String proposalId;
  final String accountScopeId;
  final String surfaceId;
  final String baseDomainRevision;
  final String displayedDiffDigest;
  final List<String> selectedOperationIds;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String bindingDigest;

  bool validates({
    required CreatorHandshakePreview preview,
    required String currentAccountScopeId,
    required DateTime now,
  }) {
    if (surfaceId != 'creator' ||
        currentAccountScopeId != accountScopeId ||
        preview.accountScopeId != accountScopeId ||
        preview.proposalId != proposalId ||
        preview.baseDomainRevision != baseDomainRevision ||
        preview.displayedDiffDigest != displayedDiffDigest ||
        !setEquals(
          preview.selectedOperationIds,
          selectedOperationIds.toSet(),
        ) ||
        !now.toUtc().isBefore(expiresAt)) {
      return false;
    }
    final Map<String, Object?> binding = <String, Object?>{
      'accountScopeId': accountScopeId,
      'baseDomainRevision': baseDomainRevision,
      'displayedDiffDigest': displayedDiffDigest,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'personContextBinding': preview.personContextBinding?.toCanonicalJson(),
      'proposalId': proposalId,
      'selectedOperationIds': selectedOperationIds,
      'surfaceId': surfaceId,
    };
    return creatorHandshakeDigest(binding) == bindingDigest;
  }
}

final class CreatorEntityId {
  const CreatorEntityId({required this.kind, required this.id});

  final CreatorEntityKind kind;
  final String id;
}

final class CreatorHandshakeReceipt {
  CreatorHandshakeReceipt({
    required this.proposalId,
    required this.accountScopeId,
    required this.confirmationTokenId,
    required List<String> appliedOperationIds,
    required List<String> taskIds,
    List<CreatorEntityId> entityIds = const <CreatorEntityId>[],
    required this.appliedAt,
    required this.undoExpiresAt,
    required this.resultingDomainRevision,
  }) : appliedOperationIds = List<String>.unmodifiable(appliedOperationIds),
       taskIds = List<String>.unmodifiable(taskIds),
       entityIds = List<CreatorEntityId>.unmodifiable(
         entityIds.isEmpty && taskIds.isNotEmpty
             ? taskIds.map(
                 (String id) =>
                     CreatorEntityId(kind: CreatorEntityKind.task, id: id),
               )
             : entityIds,
       );

  final String proposalId;
  final String accountScopeId;
  final String confirmationTokenId;
  final List<String> appliedOperationIds;
  final List<String> taskIds;
  final List<CreatorEntityId> entityIds;
  final DateTime appliedAt;
  final DateTime undoExpiresAt;
  final String resultingDomainRevision;

  List<CreatorEntityId> get typedEntityIds => entityIds;
  List<String> get goalIds => _idsFor(CreatorEntityKind.goal);
  List<String> get habitIds => _idsFor(CreatorEntityKind.habit);
  List<String> get noteIds => _idsFor(CreatorEntityKind.note);

  bool canUndoAt(DateTime now) => now.toUtc().isBefore(undoExpiresAt.toUtc());

  List<String> _idsFor(CreatorEntityKind kind) => List<String>.unmodifiable(
    entityIds
        .where((CreatorEntityId value) => value.kind == kind)
        .map((CreatorEntityId value) => value.id),
  );
}

final class CreatorHandshakeState {
  const CreatorHandshakeState({
    this.phase = CreatorHandshakePhase.idle,
    this.preview,
    this.token,
    this.receipt,
    this.message,
    this.formRevision = 0,
  });

  final CreatorHandshakePhase phase;
  final CreatorHandshakePreview? preview;
  final CreatorConfirmationToken? token;
  final CreatorHandshakeReceipt? receipt;
  final String? message;
  final int formRevision;

  bool get isReviewing => preview != null && receipt == null;
  bool get canConfirm =>
      isReviewing &&
      preview!.selectedOperationIds.isNotEmpty &&
      phase != CreatorHandshakePhase.confirming;

  CreatorHandshakeState copyWith({
    CreatorHandshakePhase? phase,
    CreatorHandshakePreview? preview,
    CreatorConfirmationToken? token,
    CreatorHandshakeReceipt? receipt,
    String? message,
    int? formRevision,
    bool clearPreview = false,
    bool clearToken = false,
    bool clearReceipt = false,
    bool clearMessage = false,
  }) => CreatorHandshakeState(
    phase: phase ?? this.phase,
    preview: clearPreview ? null : preview ?? this.preview,
    token: clearToken ? null : token ?? this.token,
    receipt: clearReceipt ? null : receipt ?? this.receipt,
    message: clearMessage ? null : message ?? this.message,
    formRevision: formRevision ?? this.formRevision,
  );
}

bool setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

extension on CreatorMutationKind {
  CreatorEntityKind get entityKind => switch (this) {
    CreatorMutationKind.createTask => CreatorEntityKind.task,
    CreatorMutationKind.createGoal => CreatorEntityKind.goal,
    CreatorMutationKind.createHabit => CreatorEntityKind.habit,
    CreatorMutationKind.createNote => CreatorEntityKind.note,
  };
}

String creatorHandshakeDigest(Object? value) {
  final Object? canonical = _canonicalize(value);
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.map((Object? key) => '$key').toList()
      ..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map<Object?>(_canonicalize).toList(growable: false);
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value;
}
