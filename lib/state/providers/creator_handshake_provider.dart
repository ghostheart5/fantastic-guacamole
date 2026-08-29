import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/task_policy.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
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

class CreatorHandshakeNotifier extends Notifier<CreatorHandshakeState> {
  static const Duration confirmationLifetime = Duration(minutes: 5);
  static const Duration undoLifetime = Duration(seconds: 30);

  int _proposalSequence = 0;
  bool _confirmationInFlight = false;
  bool _undoInFlight = false;

  @override
  CreatorHandshakeState build() => const CreatorHandshakeState();

  Future<CreatorHandshakeState> stage({
    required CreatorFormData data,
    CreatorHandshakeSource source = CreatorHandshakeSource.creator,
  }) async {
    final String account = _verifiedAccountScopeId();
    final DateTime now = _now();
    final String revision = await _domainRevision();
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
    final CreatorTaskMutation task = _taskMutationFromForm(
      data: data,
      proposalId: proposalId,
      createdAt: now,
    );
    final CreatorMutationOperation operation = CreatorMutationOperation(
      operationId: '$proposalId:create-task',
      kind: CreatorMutationKind.createTask,
      label: 'Create ${task.creatorKind.toLowerCase()}',
      task: task,
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
    );
    final CreatorConfirmationToken token = CreatorConfirmationToken.issue(
      preview: preview,
      issuedAt: now,
    );
    state = CreatorHandshakeState(
      phase: CreatorHandshakePhase.preview,
      preview: preview,
      token: token,
      message: 'Review the exact selected change. Nothing has been saved yet.',
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
        message:
            'This confirmation was already applied. No duplicate task was created.',
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

    final String currentRevision = await _domainRevision();
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

    final ITaskRepository repository = ref.read(domainTaskRepositoryProvider);
    final Map<String, Map<String, Object?>> ledger = await _readLedger(account);
    final List<CreatorMutationOperation> toCreate =
        <CreatorMutationOperation>[];
    final List<String> taskIds = <String>[];
    bool replayOnly = true;

    for (final CreatorMutationOperation operation
        in preview.selectedOperations) {
      final Map<String, Object?>? recorded = ledger[operation.operationId];
      final String status = recorded?['status']?.toString() ?? '';
      if (status == 'applied' || status == 'undone') {
        taskIds.add(operation.task.taskId);
        continue;
      }
      final TaskEntity? existing = await repository.getTaskById(
        operation.task.taskId,
      );
      if (existing != null) {
        if (!_matchesMutation(existing, operation.task)) {
          state = state.copyWith(
            phase: CreatorHandshakePhase.conflict,
            message:
                'The target task identity is already used by different data. Nothing was changed.',
          );
          return state;
        }
        ledger[operation.operationId] = _ledgerEntry(
          operation,
          status: 'applied',
          timestamp: now,
        );
        taskIds.add(operation.task.taskId);
        continue;
      }
      replayOnly = false;
      toCreate.add(operation);
      taskIds.add(operation.task.taskId);
    }

    try {
      for (final CreatorMutationOperation operation in toCreate) {
        final TaskEntity task = _entityFromMutation(operation.task);
        if (!TaskPolicy.isValid(task)) {
          throw StateError('The confirmed task no longer passes validation.');
        }
        await repository.saveTask(task);
        _bestEffort(
          () => ref.read(localMetricsAccumulatorProvider).recordTaskCreated(),
        ).ignore();
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
      appliedAt: now,
      undoExpiresAt: now.add(undoLifetime),
      resultingDomainRevision: resultingRevision,
    );
    ref.invalidate(tasksProvider);
    state = state.copyWith(
      phase: replayOnly
          ? CreatorHandshakePhase.idempotent
          : CreatorHandshakePhase.applied,
      receipt: receipt,
      message: replayOnly
          ? 'This confirmation was already applied. No duplicate task was created.'
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
        message: '${error.message} The saved task was not changed.',
      );
      return state;
    }
    if (account != receipt.accountScopeId) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.conflict,
        message:
            'Undo is bound to another account. The saved task was not changed.',
      );
      return state;
    }
    final DateTime now = _now();
    if (!receipt.canUndoAt(now)) {
      state = state.copyWith(
        phase: CreatorHandshakePhase.expired,
        message: 'The undo window expired. The saved task was not changed.',
      );
      return state;
    }

    final ITaskRepository repository = ref.read(domainTaskRepositoryProvider);
    final Map<String, Map<String, Object?>> ledger = await _readLedger(account);
    for (final CreatorMutationOperation operation
        in preview.selectedOperations) {
      final TaskEntity? existing = await repository.getTaskById(
        operation.task.taskId,
      );
      if (existing == null) {
        ledger[operation.operationId] = _ledgerEntry(
          operation,
          status: 'undone',
          timestamp: now,
        );
        continue;
      }
      if (!_matchesMutation(existing, operation.task)) {
        state = state.copyWith(
          phase: CreatorHandshakePhase.conflict,
          message:
              'The created task changed after confirmation, so automatic undo was blocked.',
        );
        return state;
      }
    }

    try {
      for (final CreatorMutationOperation operation
          in preview.selectedOperations) {
        final TaskEntity? existing = await repository.getTaskById(
          operation.task.taskId,
        );
        if (existing != null) {
          await repository.deleteTask(operation.task.taskId);
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
            'Undo could not complete. The current task state was preserved.',
      );
      return state;
    }
    await _bestEffort(() => _writeLedger(account, ledger));
    ref.invalidate(tasksProvider);
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

  CreatorTaskMutation _taskMutationFromForm({
    required CreatorFormData data,
    required String proposalId,
    required DateTime createdAt,
  }) {
    final String kind = data.type.trim().toLowerCase();
    final recurrence = data.recurrenceRule.name != 'none'
        ? data.recurrenceRule
        : switch (kind) {
            'routine' => RecurrenceRule.daily,
            _ => data.recurrenceRule,
          };
    final int difficulty = kind == 'goal' ? 5 : 3;
    final int energyRequired = switch (kind) {
      'goal' => 4,
      'routine' => 2,
      'note' => 1,
      _ => 3,
    };
    final int priority = switch (kind) {
      'goal' => data.priority < 4 ? 4 : data.priority,
      'note' => 1,
      _ => data.priority,
    };
    return CreatorTaskMutation(
      taskId:
          'creator-task-${creatorHandshakeDigest(proposalId).substring(0, 24)}',
      creatorKind: kind.isEmpty ? 'task' : kind,
      title: data.title.trim(),
      description: data.description?.trim().isEmpty ?? true
          ? null
          : data.description!.trim(),
      priority: priority,
      difficulty: difficulty,
      energyRequired: energyRequired,
      createdAt: createdAt,
      scheduledFor: data.scheduledFor,
      recurrenceRule: recurrence,
    );
  }

  TaskEntity _entityFromMutation(CreatorTaskMutation mutation) => TaskEntity(
    id: mutation.taskId,
    title: mutation.title,
    description: mutation.description,
    createdAt: mutation.createdAt,
    priority: mutation.priority,
    difficulty: mutation.difficulty,
    energyRequired: mutation.energyRequired,
    scheduledFor: mutation.scheduledFor,
    occurrenceKey: TaskEntity.deriveOccurrenceKey(
      taskId: mutation.taskId,
      createdAt: mutation.createdAt,
    ),
    recurrenceRule: mutation.recurrenceRule,
  );

  bool _matchesMutation(TaskEntity task, CreatorTaskMutation mutation) {
    final TaskEntity expected = _entityFromMutation(mutation);
    return task.id == expected.id &&
        task.title == expected.title &&
        task.description == expected.description &&
        task.createdAt.toUtc() == expected.createdAt.toUtc() &&
        task.priority == expected.priority &&
        task.difficulty == expected.difficulty &&
        task.energyRequired == expected.energyRequired &&
        task.scheduledFor?.toUtc() == expected.scheduledFor?.toUtc() &&
        task.updatedAt == null &&
        task.estimatedDuration == null &&
        task.occurrenceKey == expected.occurrenceKey &&
        task.dueDate == null &&
        task.goalId == null &&
        task.subtasks.isEmpty &&
        task.recurrenceRule == expected.recurrenceRule &&
        !task.isCompleted &&
        !task.isSkipped &&
        !task.isCanceled;
  }

  Future<String> _domainRevision() async {
    final List<TaskEntity> tasks = List<TaskEntity>.of(
      await ref.read(domainTaskRepositoryProvider).getAllTasks(),
    );
    tasks.sort(
      (TaskEntity left, TaskEntity right) => left.id.compareTo(right.id),
    );
    return 'tasks-v1-${creatorHandshakeDigest(tasks.map((TaskEntity task) => task.toJson()).toList(growable: false)).substring(0, 32)}';
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
    'taskId': operation.task.taskId,
    'taskDigest': operation.task.digest,
    'status': status,
    'updatedAt': timestamp.toUtc().toIso8601String(),
  };

  Future<void> _recordGuidanceMilestones(
    CreatorHandshakePreview preview,
  ) async {
    final AdaptiveGuidanceNotifier guidance = ref.read(
      adaptiveGuidanceProvider.notifier,
    );
    await guidance.recordIfMissing(GuidanceMilestone.firstItem);
    if (preview.selectedOperations.any(
      (CreatorMutationOperation operation) =>
          operation.task.scheduledFor != null,
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
