import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creatorHandshakeClockProvider = Provider<DateTime Function()>(
  (Ref ref) =>
      () => DateTime.now().toUtc(),
);

final creatorHandshakeProvider =
    NotifierProvider<CreatorHandshakeNotifier, CreatorHandshakeState>(
      CreatorHandshakeNotifier.new,
    );

final PersonContextAccessRequest _creatorPersonContextRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.creator,
      purposes: operationalPersonContextPurposes,
    );

class CreatorHandshakeNotifier extends Notifier<CreatorHandshakeState> {
  static const Duration confirmationLifetime = Duration(minutes: 5);
  static const Duration undoLifetime = Duration(seconds: 30);

  int _proposalSequence = 0;
  bool _confirmationInFlight = false;
  bool _undoInFlight = false;

  @override
  CreatorHandshakeState build() {
    ref.listen<PersonContextView?>(
      personContextForSurfaceProvider(_creatorPersonContextRequest),
      (PersonContextView? previous, PersonContextView? next) {
        final CreatorHandshakeState current = state;
        final CreatorHandshakePreview? preview = current.preview;
        if (preview == null ||
            current.token == null ||
            current.receipt != null) {
          return;
        }
        if (!_personContextBindingMatchesView(
          preview.personContextBinding,
          next,
          preview.accountScopeId,
          preview.operations.single.mutation,
        )) {
          _rejectStalePersonContext();
        }
      },
    );
    return const CreatorHandshakeState();
  }

  Future<CreatorHandshakeState> stage({
    required CreatorFormData data,
    CreatorHandshakeSource source = CreatorHandshakeSource.creator,
  }) async {
    final String account = _verifiedAccountScopeId();
    final DateTime now = _now();
    final String revision = await _domainRevision();
    final PersonContextView? personContext = _creatorPersonContext(account);
    final int sequence = _proposalSequence++;
    final String proposalSeed = creatorHandshakeDigest(<String, Object?>{
      'account': account,
      'createdAt': now.toIso8601String(),
      'sequence': sequence,
      'source': source.name,
      'title': data.title.trim(),
    });
    final String proposalId =
        'creator-proposal-${proposalSeed.substring(0, 24)}';
    final CreatorEntityMutation mutation = _mutationFromForm(
      data: data,
      proposalId: proposalId,
      createdAt: now,
    );
    final CreatorPersonContextBinding? personContextBinding =
        personContext == null
        ? null
        : _personContextBinding(personContext, mutation: mutation, now: now);
    final CreatorMutationOperation operation = CreatorMutationOperation(
      operationId: '$proposalId:create-${mutation.entityKind.name}',
      kind: switch (mutation.entityKind) {
        CreatorEntityKind.task => CreatorMutationKind.createTask,
        CreatorEntityKind.goal => CreatorMutationKind.createGoal,
        CreatorEntityKind.habit => CreatorMutationKind.createHabit,
        CreatorEntityKind.note => CreatorMutationKind.createNote,
      },
      label: 'Create ${_entityLabel(mutation.entityKind).toLowerCase()}',
      mutation: mutation,
    );
    final CreatorHandshakePreview preview = CreatorHandshakePreview(
      proposalId: proposalId,
      accountScopeId: account,
      source: source,
      baseDomainRevision: revision,
      createdAt: now,
      expiresAt: now.add(confirmationLifetime),
      operations: <CreatorMutationOperation>[operation],
      selectedOperationIds: <String>{operation.operationId},
      personContextBinding: personContextBinding,
    );
    final CreatorConfirmationToken token = CreatorConfirmationToken.issue(
      preview: preview,
      issuedAt: now,
    );
    state = CreatorHandshakeState(
      phase: CreatorHandshakePhase.preview,
      preview: preview,
      token: token,
      message: personContextBinding?.hasBoundEvidence ?? false
          ? 'Review the exact selected change and its governed Person Context warnings. The proposed ${_entityLabel(mutation.entityKind).toLowerCase()} was not silently rewritten. Explicit confirmation is required; nothing has been saved yet.'
          : 'Review the exact selected change. Nothing has been saved yet.',
      formRevision: state.formRevision,
    );
    return state;
  }

  void toggleOperation(String operationId, {required bool selected}) {
    final CreatorHandshakePreview? current = state.preview;
    if (current == null || state.receipt != null) return;
    final Set<String> selectedIds = current.selectedOperationIds.toSet();
    if (selected) {
      selectedIds.add(operationId);
    } else {
      selectedIds.remove(operationId);
    }
    final DateTime now = _now();
    final CreatorHandshakePreview updated = current.copyWith(
      createdAt: now,
      expiresAt: now.add(confirmationLifetime),
      selectedOperationIds: selectedIds,
    );
    state = state.copyWith(
      phase: CreatorHandshakePhase.preview,
      preview: updated,
      token: selectedIds.isEmpty
          ? null
          : CreatorConfirmationToken.issue(preview: updated, issuedAt: now),
      clearToken: selectedIds.isEmpty,
      message: selectedIds.isEmpty
          ? 'Select at least one operation to enable confirmation.'
          : 'Selection updated. Review the bound diff before confirming.',
    );
  }

  void cancelPreview() {
    if (state.phase == CreatorHandshakePhase.confirming) return;
    state = CreatorHandshakeState(formRevision: state.formRevision);
  }

  void clearResult() {
    if (_confirmationInFlight || _undoInFlight) return;
    state = CreatorHandshakeState(formRevision: state.formRevision);
  }

  Future<CreatorHandshakeState> confirm() async {
    if (_confirmationInFlight) return state;
    _confirmationInFlight = true;
    try {
      return await _confirmOnce();
    } finally {
      _confirmationInFlight = false;
    }
  }

  Future<CreatorHandshakeState> _confirmOnce() async {
    if (state.receipt != null) {
      if (state.phase == CreatorHandshakePhase.undone) {
        return state;
      }
      state = state.copyWith(
        phase: CreatorHandshakePhase.idempotent,
        message: _idempotentMessage(state.preview),
      );
      return state;
    }
    final CreatorHandshakePreview? preview = state.preview;
    final CreatorConfirmationToken? token = state.token;
    if (preview == null ||
        token == null ||
        preview.selectedOperations.isEmpty) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.conflict,
        message: 'No bound Creator operation is selected. Nothing was saved.',
      );
      return state;
    }

    final String account;
    try {
      account = _verifiedAccountScopeId();
    } on StateError catch (error) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.conflict,
        message: '${error.message} Nothing was saved.',
      );
      return state;
    }
    final DateTime now = _now();
    if (preview.isExpiredAt(now)) {
      return _refreshPreview(
        preview,
        phase: CreatorHandshakePhase.expired,
        message:
            'Confirmation expired. The preview was refreshed; review it again. Nothing was saved.',
      );
    }
    if (!token.validates(
      preview: preview,
      currentAccountScopeId: account,
      now: now,
    )) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.conflict,
        message:
            'Confirmation binding did not match the displayed diff. Nothing was saved.',
      );
      return state;
    }

    if (!_personContextBindingIsCurrent(preview, account)) {
      return _rejectStalePersonContext();
    }

    final String currentRevision = await _domainRevision();
    if (!_personContextBindingIsCurrent(preview, account)) {
      return _rejectStalePersonContext();
    }
    if (currentRevision != preview.baseDomainRevision) {
      return _refreshPreview(
        preview,
        phase: CreatorHandshakePhase.stale,
        revision: currentRevision,
        message:
            'Creator data changed after this preview. Review the refreshed version before confirming. Nothing was saved.',
      );
    }

    state = state.copyWith(
      phase: CreatorHandshakePhase.confirming,
      message: 'Applying only the selected, confirmed operation…',
    );

    final Map<String, Map<String, Object?>> ledger = await _readLedger(account);
    final List<CreatorMutationOperation> toCreate =
        <CreatorMutationOperation>[];
    final List<String> taskIds = <String>[];
    final List<CreatorEntityId> entityIds = <CreatorEntityId>[];
    bool replayOnly = true;

    for (final CreatorMutationOperation operation
        in preview.selectedOperations) {
      final CreatorEntityId entityId = CreatorEntityId(
        kind: operation.entityKind,
        id: operation.entityId,
      );
      entityIds.add(entityId);
      if (operation.entityKind == CreatorEntityKind.task) {
        taskIds.add(operation.entityId);
      }
      final Map<String, Object?>? recorded = ledger[operation.operationId];
      final String status = recorded?['status']?.toString() ?? '';
      if (status == 'applied' || status == 'undone') {
        if (!_ledgerEntryMatches(recorded!, operation)) {
          state = state.copyWith(
            phase: CreatorHandshakePhase.conflict,
            message:
                'The saved replay record does not match the confirmed ${_entityLabel(operation.entityKind).toLowerCase()}. Nothing was changed.',
          );
          return state;
        }
        continue;
      }
      final Object? existing = await _readExisting(operation);
      if (existing != null) {
        if (!_matchesMutation(existing, operation)) {
          state = state.copyWith(
            phase: CreatorHandshakePhase.conflict,
            message:
                'The target ${_entityLabel(operation.entityKind).toLowerCase()} identity is already used by different data. Nothing was changed.',
          );
          return state;
        }
        ledger[operation.operationId] = _ledgerEntry(
          operation,
          status: 'applied',
          timestamp: now,
        );
        continue;
      }
      replayOnly = false;
      toCreate.add(operation);
    }

    try {
      for (final CreatorMutationOperation operation in toCreate) {
        if (!_personContextBindingIsCurrent(preview, account)) {
          return _rejectStalePersonContext();
        }
        await _applyCreate(operation);
        if (operation.entityKind == CreatorEntityKind.task) {
          _bestEffort(
            () => ref.read(localMetricsAccumulatorProvider).recordTaskCreated(),
          ).ignore();
        }
        ledger[operation.operationId] = _ledgerEntry(
          operation,
          status: 'applied',
          timestamp: now,
        );
      }
    } on Object {
      state = state.copyWith(
        phase: CreatorHandshakePhase.failed,
        message:
            'Creator could not finish the confirmed operation. Review the current data before retrying.',
      );
      return state;
    }

    await _bestEffort(() => _writeLedger(account, ledger));
    await _bestEffort(() => _recordGuidanceMilestones(preview));
    final String resultingRevision = await _domainRevision();
    final CreatorHandshakeReceipt receipt = CreatorHandshakeReceipt(
      proposalId: preview.proposalId,
      accountScopeId: account,
      confirmationTokenId: token.tokenId,
      appliedOperationIds: preview.selectedOperationIds.toList()..sort(),
      taskIds: List<String>.unmodifiable(taskIds),
      entityIds: entityIds,
      appliedAt: now,
      undoExpiresAt: now.add(undoLifetime),
      resultingDomainRevision: resultingRevision,
    );
    _invalidateDomains(preview.selectedOperations);
    state = state.copyWith(
      phase: replayOnly
          ? CreatorHandshakePhase.idempotent
          : CreatorHandshakePhase.applied,
      receipt: receipt,
      message: replayOnly
          ? _idempotentMessage(preview)
          : 'Saved exactly once from the selected confirmation.',
      formRevision: state.formRevision + 1,
    );
    return state;
  }

  Future<CreatorHandshakeState> undo() async {
    if (_undoInFlight) return state;
    _undoInFlight = true;
    try {
      return await _undoOnce();
    } finally {
      _undoInFlight = false;
    }
  }

  Future<CreatorHandshakeState> _undoOnce() async {
    final CreatorHandshakeReceipt? receipt = state.receipt;
    final CreatorHandshakePreview? preview = state.preview;
    if (receipt == null || preview == null) return state;
    final String account;
    try {
      account = _verifiedAccountScopeId();
    } on StateError catch (error) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.conflict,
        message: '${error.message} The saved item was not changed.',
      );
      return state;
    }
    if (account != receipt.accountScopeId) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.conflict,
        message:
            'Undo is bound to another account. The saved item was not changed.',
      );
      return state;
    }
    final DateTime now = _now();
    if (!receipt.canUndoAt(now)) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.expired,
        message: 'The undo window expired. The saved item was not changed.',
      );
      return state;
    }

    final Map<String, Map<String, Object?>> ledger = await _readLedger(account);
    for (final CreatorMutationOperation operation
        in preview.selectedOperations) {
      final Map<String, Object?>? recorded = ledger[operation.operationId];
      if (recorded != null && !_ledgerEntryMatches(recorded, operation)) {
        state = state.copyWith(
          phase: CreatorHandshakePhase.conflict,
          message:
              'The undo record no longer matches the confirmed ${_entityLabel(operation.entityKind).toLowerCase()}. Nothing was changed.',
        );
        return state;
      }
      final Object? existing = await _readExisting(operation);
      if (existing == null) {
        ledger[operation.operationId] = _ledgerEntry(
          operation,
          status: 'undone',
          timestamp: now,
        );
        continue;
      }
      if (!_matchesMutation(existing, operation)) {
        state = state.copyWith(
          phase: CreatorHandshakePhase.conflict,
          message:
              'The created ${_entityLabel(operation.entityKind).toLowerCase()} changed after confirmation, so automatic undo was blocked.',
        );
        return state;
      }
    }

    try {
      for (final CreatorMutationOperation operation
          in preview.selectedOperations) {
        final Object? existing = await _readExisting(operation);
        if (existing != null) {
          await _applyDelete(operation);
        }
        ledger[operation.operationId] = _ledgerEntry(
          operation,
          status: 'undone',
          timestamp: now,
        );
      }
    } on Object {
      state = state.copyWith(
        phase: CreatorHandshakePhase.failed,
        message:
            'Undo could not complete. The current item state was preserved.',
      );
      return state;
    }
    await _bestEffort(() => _writeLedger(account, ledger));
    _invalidateDomains(preview.selectedOperations);
    state = state.copyWith(
      phase: CreatorHandshakePhase.undone,
      message:
          'Creation undone. Repeated undo requests will not mutate data again.',
    );
    return state;
  }

  Future<CreatorHandshakeState> _refreshPreview(
    CreatorHandshakePreview preview, {
    required CreatorHandshakePhase phase,
    required String message,
    String? revision,
  }) async {
    final DateTime now = _now();
    final CreatorHandshakePreview refreshed = preview.copyWith(
      baseDomainRevision: revision ?? await _domainRevision(),
      createdAt: now,
      expiresAt: now.add(confirmationLifetime),
    );
    state = state.copyWith(
      phase: phase,
      preview: refreshed,
      token: CreatorConfirmationToken.issue(preview: refreshed, issuedAt: now),
      message: message,
    );
    return state;
  }

  CreatorEntityMutation _mutationFromForm({
    required CreatorFormData data,
    required String proposalId,
    required DateTime createdAt,
  }) {
    final String title = data.title.trim();
    final String? description = data.description?.trim().isEmpty ?? true
        ? null
        : data.description!.trim();
    final String idDigest = creatorHandshakeDigest(
      data.kind == CreatorFormKind.task
          ? proposalId
          : '$proposalId:${data.kind.name}',
    ).substring(0, 24);
    return switch (data.kind) {
      CreatorFormKind.task => CreatorTaskMutation(
        taskId: 'creator-task-$idDigest',
        creatorKind: 'task',
        title: title,
        description: description,
        priority: data.priority,
        difficulty: 3,
        energyRequired: 3,
        createdAt: createdAt,
        goalId: _trimmedOrNull(data.goalId),
        estimatedDuration: data.estimatedDuration,
        dueDate: data.dueDate,
        scheduledFor: data.scheduledFor,
        recurrenceRule: data.recurrenceRule,
      ),
      CreatorFormKind.goal => CreatorGoalMutation(
        goalId: 'creator-goal-$idDigest',
        title: title,
        description: description,
        createdAt: createdAt,
        targetDate: data.targetDate ?? data.dueDate ?? data.scheduledFor,
        colorHex: data.goalColorHex,
      ),
      CreatorFormKind.habit => CreatorHabitMutation(
        habitId: 'creator-habit-$idDigest',
        title: title,
        description: description,
        createdAt: createdAt,
        cadence: switch (data.recurrenceRule) {
          RecurrenceRule.daily => HabitCadence.daily,
          RecurrenceRule.weekly => HabitCadence.weekly,
          RecurrenceRule.none => data.habitCadence,
        },
        targetCount: data.habitTargetCount.clamp(1, 365),
      ),
      CreatorFormKind.note => CreatorNoteMutation(
        noteId: 'creator-note-$idDigest',
        title: title,
        body: description,
        createdAt: createdAt,
      ),
    };
  }

  PersonContextView? _creatorPersonContext(String accountScopeId) {
    final PersonContextView? view = ref.read(
      personContextForSurfaceProvider(_creatorPersonContextRequest),
    );
    if (view == null ||
        view.accountScopeId != accountScopeId ||
        view.surface != PersonContextSurface.creator ||
        !setEquals(view.purposes, operationalPersonContextPurposes)) {
      return null;
    }
    return view;
  }

  CreatorPersonContextBinding _personContextBinding(
    PersonContextView view, {
    required CreatorEntityMutation mutation,
    required DateTime now,
  }) {
    final TaskEntity? proposedTask = mutation is CreatorTaskMutation
        ? _taskEntityFromMutation(mutation)
        : null;
    final GovernedDecisionContext context = GovernedDecisionContext.resolve(
      view: view,
      accountScopeId: view.accountScopeId,
      tasks: proposedTask == null
          ? const <TaskEntity>[]
          : <TaskEntity>[proposedTask],
      now: now,
      surface: PersonContextSurface.creator,
    );
    final Set<String> usedSignalIds = context.appliedSignalIds;
    final List<PersonContextSignal> guidanceSignals =
        view.signals
            .where(
              (PersonContextSignal signal) => usedSignalIds.contains(signal.id),
            )
            .toList(growable: true)
          ..sort(PersonContextBehaviorPolicy.compareSignals);
    final List<String> evidenceSummary = guidanceSignals
        .map(_creatorEvidenceSummary)
        .toList(growable: false);
    final int? capacityCapMinutes = context.capacityCapMinutes;
    final List<String> warnings = <String>[
      if (proposedTask != null &&
          context.excludedTaskIds.contains(proposedTask.id))
        'This proposal conflicts with an explicit boundary.',
      if (proposedTask != null &&
          capacityCapMinutes != null &&
          proposedTask.estimateOrDefault.inMinutes > capacityCapMinutes)
        'The ${proposedTask.estimateOrDefault.inMinutes}-minute estimate exceeds the fresh user-reported $capacityCapMinutes-minute capacity.',
      if (proposedTask != null &&
          context.protectedCommitmentTaskIds.contains(proposedTask.id))
        'This proposal matches a fresh user-reported commitment; confirm timing and duplication before saving.',
    ];
    return CreatorPersonContextBinding(
      revision: _personContextRevision(view, evidenceSummary),
      hasBoundEvidence: evidenceSummary.isNotEmpty,
      evidenceSummary: evidenceSummary,
      conflictWarnings: warnings,
      behaviorTrace: context.trace?.toJson() ?? const <String, Object?>{},
    );
  }

  String _personContextRevision(
    PersonContextView view,
    List<String> displayedEvidence,
  ) {
    final String digest = creatorHandshakeDigest(<String, Object?>{
      'accountScopeId': view.accountScopeId,
      'displayedEvidence': displayedEvidence,
      'purposes':
          view.purposes
              .map((PersonContextPurpose value) => value.name)
              .toList(growable: false)
            ..sort(),
      'surface': view.surface.name,
    });
    return 'person-context-v1-${digest.substring(0, 32)}';
  }

  bool _personContextBindingIsCurrent(
    CreatorHandshakePreview preview,
    String account,
  ) {
    final PersonContextView? currentContext = _creatorPersonContext(account);
    return _personContextBindingMatchesView(
      preview.personContextBinding,
      currentContext,
      account,
      preview.operations.single.mutation,
    );
  }

  bool _personContextBindingMatchesView(
    CreatorPersonContextBinding? binding,
    PersonContextView? view,
    String account,
    CreatorEntityMutation mutation,
  ) {
    if (binding == null) return view == null;
    if (view == null ||
        view.accountScopeId != account ||
        view.surface != PersonContextSurface.creator ||
        !setEquals(view.purposes, operationalPersonContextPurposes)) {
      return false;
    }
    return _personContextBinding(
          view,
          mutation: mutation,
          now: _now(),
        ).revision ==
        binding.revision;
  }

  CreatorHandshakeState _rejectStalePersonContext() {
    state = state.copyWith(
      phase: CreatorHandshakePhase.stale,
      clearToken: true,
      message:
          'Person context changed after this preview. Stage and review a new proposal before confirming. Nothing was saved.',
    );
    return state;
  }

  String _creatorEvidenceSummary(PersonContextSignal signal) {
    return '${signal.kind.name}: ${signal.value}';
  }

  TaskEntity _taskEntityFromMutation(CreatorTaskMutation mutation) =>
      TaskEntity(
        id: mutation.taskId,
        title: mutation.title,
        description: mutation.description,
        createdAt: mutation.createdAt,
        priority: mutation.priority,
        difficulty: mutation.difficulty,
        energyRequired: mutation.energyRequired,
        estimatedDuration: mutation.estimatedDuration,
        scheduledFor: mutation.scheduledFor,
        dueDate: mutation.dueDate,
        goalId: mutation.goalId,
        occurrenceKey: TaskEntity.deriveOccurrenceKey(
          taskId: mutation.taskId,
          createdAt: mutation.createdAt,
        ),
        recurrenceRule: mutation.recurrenceRule,
      );

  GoalEntity _goalEntityFromMutation(CreatorGoalMutation mutation) =>
      GoalEntity(
        id: mutation.goalId,
        title: mutation.title,
        createdAt: mutation.createdAt,
        description: mutation.description,
        targetDate: mutation.targetDate,
        colorHex: mutation.colorHex,
      );

  HabitEntity _habitEntityFromMutation(CreatorHabitMutation mutation) =>
      HabitEntity(
        id: mutation.habitId,
        title: mutation.title,
        description: mutation.description,
        createdAt: mutation.createdAt,
        updatedAt: mutation.createdAt,
        cadence: mutation.cadence,
        targetCount: mutation.targetCount,
      );

  NoteEntity _noteEntityFromMutation(CreatorNoteMutation mutation) =>
      NoteEntity(
        id: mutation.noteId,
        title: mutation.title,
        body: mutation.body,
        createdAt: mutation.createdAt,
        updatedAt: mutation.createdAt,
      );

  Future<Object?> _readExisting(CreatorMutationOperation operation) async {
    switch (operation.mutation) {
      case final CreatorTaskMutation mutation:
        return ref
            .read(domainTaskRepositoryProvider)
            .getTaskById(mutation.taskId);
      case final CreatorGoalMutation mutation:
        return _goalById(
          ref.read(domainGoalRepositoryProvider).getGoals(),
          mutation.goalId,
        );
      case final CreatorHabitMutation mutation:
        return _habitById(
          await ref.read(domainHabitRepositoryProvider).getHabits(),
          mutation.habitId,
        );
      case final CreatorNoteMutation mutation:
        return _noteById(
          await ref.read(domainNoteRepositoryProvider).getNotes(),
          mutation.noteId,
        );
      default:
        throw StateError('Creator operation is missing a typed mutation.');
    }
  }

  Future<void> _applyCreate(CreatorMutationOperation operation) async {
    switch (operation.mutation) {
      case final CreatorTaskMutation mutation:
        final TaskEntity task = _taskEntityFromMutation(mutation);
        if (!TaskPolicy.isValid(task)) {
          throw StateError('The confirmed task no longer passes validation.');
        }
        await ref.read(domainTaskRepositoryProvider).saveTask(task);
        return;
      case final CreatorGoalMutation mutation:
        await ref
            .read(createGoalUseCaseProvider)
            .call(_goalEntityFromMutation(mutation));
        return;
      case final CreatorHabitMutation mutation:
        final List<HabitEntity> current = await ref
            .read(domainHabitRepositoryProvider)
            .getHabits();
        await ref.read(saveHabitsUseCaseProvider).call(<HabitEntity>[
          _habitEntityFromMutation(mutation),
          ...current,
        ]);
        return;
      case final CreatorNoteMutation mutation:
        final NoteEntity? created = await ref
            .read(createNoteUseCaseProvider)
            .call(
              title: mutation.title,
              body: mutation.body,
              id: mutation.noteId,
              now: mutation.createdAt,
            );
        if (created == null) {
          throw StateError('The confirmed note no longer passes validation.');
        }
        return;
      default:
        throw StateError('Creator operation is missing a typed mutation.');
    }
  }

  Future<void> _applyDelete(CreatorMutationOperation operation) async {
    switch (operation.mutation) {
      case final CreatorTaskMutation mutation:
        await ref.read(deleteTaskUseCaseProvider).call(mutation.taskId);
        return;
      case final CreatorGoalMutation mutation:
        await ref.read(deleteGoalUseCaseProvider).call(mutation.goalId);
        return;
      case final CreatorHabitMutation mutation:
        final List<HabitEntity> current = await ref
            .read(domainHabitRepositoryProvider)
            .getHabits();
        await ref
            .read(deleteHabitUseCaseProvider)
            .call(current: current, id: mutation.habitId);
        return;
      case final CreatorNoteMutation mutation:
        await ref.read(deleteNoteUseCaseProvider).call(mutation.noteId);
        return;
      default:
        throw StateError('Creator operation is missing a typed mutation.');
    }
  }

  bool _matchesMutation(Object existing, CreatorMutationOperation operation) {
    switch (operation.mutation) {
      case final CreatorTaskMutation mutation:
        if (existing is! TaskEntity) return false;
        final TaskEntity expected = _taskEntityFromMutation(mutation);
        return existing.id == expected.id &&
            existing.title == expected.title &&
            existing.description == expected.description &&
            _sameInstant(existing.createdAt, expected.createdAt) &&
            existing.priority == expected.priority &&
            existing.difficulty == expected.difficulty &&
            existing.energyRequired == expected.energyRequired &&
            existing.estimatedDuration == expected.estimatedDuration &&
            _sameOptionalInstant(
              existing.scheduledFor,
              expected.scheduledFor,
            ) &&
            existing.updatedAt == null &&
            existing.occurrenceKey == expected.occurrenceKey &&
            _sameOptionalInstant(existing.dueDate, expected.dueDate) &&
            existing.goalId == expected.goalId &&
            existing.subtasks.isEmpty &&
            existing.recurrenceRule == expected.recurrenceRule &&
            !existing.isCompleted &&
            !existing.isSkipped &&
            !existing.isCanceled;
      case final CreatorGoalMutation mutation:
        if (existing is! GoalEntity) return false;
        final GoalEntity expected = _goalEntityFromMutation(mutation);
        return existing.id == expected.id &&
            existing.title == expected.title &&
            existing.description == expected.description &&
            _sameInstant(existing.createdAt, expected.createdAt) &&
            _sameOptionalInstant(existing.targetDate, expected.targetDate) &&
            existing.colorHex == expected.colorHex &&
            existing.completedAt == null;
      case final CreatorHabitMutation mutation:
        if (existing is! HabitEntity) return false;
        final HabitEntity expected = _habitEntityFromMutation(mutation);
        return existing.id == expected.id &&
            existing.title == expected.title &&
            existing.description == expected.description &&
            _sameInstant(existing.createdAt, expected.createdAt) &&
            _sameInstant(existing.updatedAt, expected.updatedAt) &&
            existing.userId == null &&
            existing.cadence == expected.cadence &&
            existing.targetCount == expected.targetCount &&
            existing.stepTaskIds.isEmpty &&
            existing.status == HabitStatus.active;
      case final CreatorNoteMutation mutation:
        if (existing is! NoteEntity) return false;
        final NoteEntity expected = _noteEntityFromMutation(mutation);
        return existing.id == expected.id &&
            existing.title == expected.title &&
            existing.body == expected.body &&
            _sameInstant(existing.createdAt, expected.createdAt) &&
            _sameInstant(existing.updatedAt, expected.updatedAt) &&
            existing.userId == null &&
            !existing.isArchived &&
            existing.kind == expected.kind &&
            existing.goalId == null &&
            existing.taskId == null &&
            existing.habitId == null;
      default:
        return false;
    }
  }

  GoalEntity? _goalById(List<GoalEntity> goals, String id) {
    for (final GoalEntity goal in goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  HabitEntity? _habitById(List<HabitEntity> habits, String id) {
    for (final HabitEntity habit in habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  NoteEntity? _noteById(List<NoteEntity> notes, String id) {
    for (final NoteEntity note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  bool _sameInstant(DateTime left, DateTime right) =>
      left.toUtc() == right.toUtc();

  bool _sameOptionalInstant(DateTime? left, DateTime? right) {
    if (left == null || right == null) return left == right;
    return _sameInstant(left, right);
  }

  String? _trimmedOrNull(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _entityLabel(CreatorEntityKind kind) => switch (kind) {
    CreatorEntityKind.task => 'Task',
    CreatorEntityKind.goal => 'Goal',
    CreatorEntityKind.habit => 'Daily Rhythm',
    CreatorEntityKind.note => 'Note',
  };

  String _idempotentMessage(CreatorHandshakePreview? preview) {
    final Set<CreatorEntityKind> kinds =
        preview?.selectedOperations
            .map((CreatorMutationOperation operation) => operation.entityKind)
            .toSet() ??
        const <CreatorEntityKind>{};
    if (kinds.length == 1) {
      final String label = _entityLabel(kinds.single).toLowerCase();
      return 'This confirmation was already applied. No duplicate $label was created.';
    }
    return 'This confirmation was already applied. No duplicate items were created.';
  }

  void _invalidateDomains(Iterable<CreatorMutationOperation> operations) {
    final Set<CreatorEntityKind> kinds = operations
        .map((CreatorMutationOperation operation) => operation.entityKind)
        .toSet();
    for (final CreatorEntityKind kind in kinds) {
      switch (kind) {
        case CreatorEntityKind.task:
          ref.invalidate(tasksProvider);
          break;
        case CreatorEntityKind.goal:
          ref.invalidate(goalsProvider);
          break;
        case CreatorEntityKind.habit:
          ref.invalidate(habitsProvider);
          break;
        case CreatorEntityKind.note:
          ref.invalidate(notesProvider);
          break;
      }
    }
  }

  Future<String> _domainRevision() async {
    final List<TaskEntity> tasks = List<TaskEntity>.of(
      await ref.read(domainTaskRepositoryProvider).getAllTasks(),
    );
    final List<GoalEntity> goals = List<GoalEntity>.of(
      ref.read(domainGoalRepositoryProvider).getGoals(),
    );
    final List<HabitEntity> habits = List<HabitEntity>.of(
      await ref.read(domainHabitRepositoryProvider).getHabits(),
    );
    final List<NoteEntity> notes = List<NoteEntity>.of(
      await ref.read(domainNoteRepositoryProvider).getNotes(),
    );
    tasks.sort(
      (TaskEntity left, TaskEntity right) => left.id.compareTo(right.id),
    );
    goals.sort(
      (GoalEntity left, GoalEntity right) => left.id.compareTo(right.id),
    );
    habits.sort(
      (HabitEntity left, HabitEntity right) => left.id.compareTo(right.id),
    );
    notes.sort(
      (NoteEntity left, NoteEntity right) => left.id.compareTo(right.id),
    );
    final String digest = creatorHandshakeDigest(<String, Object?>{
      'goals': goals
          .map((GoalEntity goal) => goal.toJson())
          .toList(growable: false),
      'habits': habits
          .map((HabitEntity habit) => habit.toJson())
          .toList(growable: false),
      'notes': notes
          .map((NoteEntity note) => note.toJson())
          .toList(growable: false),
      'tasks': tasks
          .map((TaskEntity task) => task.toJson())
          .toList(growable: false),
    });
    return 'creator-domains-v2-${digest.substring(0, 32)}';
  }

  String _verifiedAccountScopeId() {
    final AccountStorageScope scope = ref.read(accountStorageScopeProvider);
    final String? account = scope.v2Namespace;
    if (!scope.isWritable || account == null || account.trim().isEmpty) {
      throw StateError(
        'Creator confirmation requires a verified account boundary.',
      );
    }
    return account;
  }

  DateTime _now() => ref.read(creatorHandshakeClockProvider)().toUtc();

  String _ledgerKey(String account) => 'creator_handshake_ledger_v1:$account';

  Future<Map<String, Map<String, Object?>>> _readLedger(String account) async {
    final String? raw = await ref
        .read(secureStoreProvider)
        .readString(_ledgerKey(account));
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, Object?>>{};
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, Object?>>{};
      return <String, Map<String, Object?>>{
        for (final MapEntry<dynamic, dynamic> entry in decoded.entries)
          if (entry.value is Map)
            entry.key.toString(): (entry.value as Map).map<String, Object?>(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ),
      };
    } on FormatException {
      return <String, Map<String, Object?>>{};
    }
  }

  Future<void> _writeLedger(
    String account,
    Map<String, Map<String, Object?>> ledger,
  ) {
    return ref
        .read(secureStoreProvider)
        .writeString(_ledgerKey(account), jsonEncode(ledger));
  }

  Map<String, Object?> _ledgerEntry(
    CreatorMutationOperation operation, {
    required String status,
    required DateTime timestamp,
  }) => <String, Object?>{
    'operationId': operation.operationId,
    'entityKind': operation.entityKind.name,
    'entityId': operation.entityId,
    'entityDigest': operation.entityDigest,
    if (operation.taskMutation case final CreatorTaskMutation task) ...{
      'taskId': task.taskId,
      'taskDigest': task.digest,
    },
    'status': status,
    'updatedAt': timestamp.toUtc().toIso8601String(),
  };

  bool _ledgerEntryMatches(
    Map<String, Object?> entry,
    CreatorMutationOperation operation,
  ) {
    final String? entityKind = entry['entityKind']?.toString();
    final String? entityId = entry['entityId']?.toString();
    final String? entityDigest = entry['entityDigest']?.toString();
    if (entityKind != null || entityId != null || entityDigest != null) {
      return entityKind == operation.entityKind.name &&
          entityId == operation.entityId &&
          entityDigest == operation.entityDigest;
    }
    final CreatorTaskMutation? task = operation.taskMutation;
    return task != null &&
        entry['taskId']?.toString() == task.taskId &&
        (entry['taskDigest']?.toString() == task.digest ||
            entry['taskDigest']?.toString() == _legacyTaskDigest(task));
  }

  String _legacyTaskDigest(CreatorTaskMutation task) {
    return creatorHandshakeDigest(<String, Object?>{
      'creatorKind': task.creatorKind,
      'createdAt': task.createdAt.toUtc().toIso8601String(),
      'description': task.description,
      'difficulty': task.difficulty,
      'energyRequired': task.energyRequired,
      'priority': task.priority,
      'recurrenceRule': task.recurrenceRule.name,
      'scheduledFor': task.scheduledFor?.toUtc().toIso8601String(),
      'taskId': task.taskId,
      'title': task.title,
    });
  }

  Future<void> _recordGuidanceMilestones(
    CreatorHandshakePreview preview,
  ) async {
    final AdaptiveGuidanceNotifier guidance = ref.read(
      adaptiveGuidanceProvider.notifier,
    );
    await guidance.recordIfMissing(GuidanceMilestone.firstItem);
    if (preview.selectedOperations.any(
      (CreatorMutationOperation operation) =>
          operation.taskMutation?.scheduledFor != null,
    )) {
      await guidance.recordIfMissing(GuidanceMilestone.firstSchedule);
    }
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // The confirmed task remains authoritative if optional telemetry,
      // guidance, or replay metadata is temporarily unavailable.
    }
  }
}
