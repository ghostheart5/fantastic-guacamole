import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task digest binds linkage, duration, due date, and schedule', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    final CreatorTaskMutation baseline = CreatorTaskMutation(
      taskId: 'task-1',
      creatorKind: 'task',
      title: 'Prepare evidence',
      description: null,
      priority: 4,
      difficulty: 3,
      energyRequired: 3,
      createdAt: now,
      goalId: 'goal-1',
      estimatedDuration: const Duration(minutes: 45),
      dueDate: now.add(const Duration(days: 1)),
      scheduledFor: now.add(const Duration(hours: 2)),
      recurrenceRule: RecurrenceRule.weekly,
    );
    final CreatorTaskMutation changedGoal = CreatorTaskMutation(
      taskId: baseline.taskId,
      creatorKind: baseline.creatorKind,
      title: baseline.title,
      description: baseline.description,
      priority: baseline.priority,
      difficulty: baseline.difficulty,
      energyRequired: baseline.energyRequired,
      createdAt: baseline.createdAt,
      goalId: 'goal-2',
      estimatedDuration: baseline.estimatedDuration,
      dueDate: baseline.dueDate,
      scheduledFor: baseline.scheduledFor,
      recurrenceRule: baseline.recurrenceRule,
    );

    expect(changedGoal.digest, isNot(baseline.digest));
  });

  test('confirmation token binds a typed Goal mutation', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    final CreatorMutationOperation operation = _goalOperation(
      now: now,
      title: 'Ship reviewed evidence',
    );
    final CreatorHandshakePreview preview = CreatorHandshakePreview(
      proposalId: 'proposal-1',
      accountScopeId: 'account-1',
      source: CreatorHandshakeSource.creator,
      baseDomainRevision: 'revision-1',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      operations: <CreatorMutationOperation>[operation],
      selectedOperationIds: <String>{operation.operationId},
    );
    final CreatorConfirmationToken token = CreatorConfirmationToken.issue(
      preview: preview,
      issuedAt: now,
    );
    final CreatorMutationOperation changed = _goalOperation(
      now: now,
      title: 'Changed after review',
    );
    final CreatorHandshakePreview tampered = CreatorHandshakePreview(
      proposalId: preview.proposalId,
      accountScopeId: preview.accountScopeId,
      source: preview.source,
      baseDomainRevision: preview.baseDomainRevision,
      createdAt: preview.createdAt,
      expiresAt: preview.expiresAt,
      operations: <CreatorMutationOperation>[changed],
      selectedOperationIds: <String>{changed.operationId},
    );

    expect(
      token.validates(
        preview: preview,
        currentAccountScopeId: preview.accountScopeId,
        now: now,
      ),
      isTrue,
    );
    expect(
      token.validates(
        preview: tampered,
        currentAccountScopeId: preview.accountScopeId,
        now: now,
      ),
      isFalse,
    );
  });

  test('legacy taskIds populate typed receipt identities', () {
    final DateTime now = DateTime.utc(2026, 8, 30, 12);
    final CreatorHandshakeReceipt receipt = CreatorHandshakeReceipt(
      proposalId: 'proposal-1',
      accountScopeId: 'account-1',
      confirmationTokenId: 'token-1',
      appliedOperationIds: const <String>['operation-1'],
      taskIds: const <String>['task-1'],
      appliedAt: now,
      undoExpiresAt: now.add(const Duration(seconds: 30)),
      resultingDomainRevision: 'revision-2',
    );

    expect(receipt.taskIds, const <String>['task-1']);
    expect(receipt.entityIds.single.kind, CreatorEntityKind.task);
    expect(receipt.entityIds.single.id, 'task-1');
  });
}

CreatorMutationOperation _goalOperation({
  required DateTime now,
  required String title,
}) {
  return CreatorMutationOperation(
    operationId: 'operation-1',
    kind: CreatorMutationKind.createGoal,
    label: 'Create goal',
    mutation: CreatorGoalMutation(
      goalId: 'goal-1',
      title: title,
      description: null,
      createdAt: now,
      targetDate: null,
      colorHex: 0xFF9B8AFB,
    ),
  );
}
