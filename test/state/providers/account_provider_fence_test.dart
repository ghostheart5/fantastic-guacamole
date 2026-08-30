import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/state/providers/account_provider_fence.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final Provider<void> _accountTransitionProvider = Provider<void>((Ref ref) {
  invalidateAccountOwnedProviders(ref);
});

void main() {
  test('account transition clears account-owned Creator preview state', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        creatorHandshakeProvider.overrideWith(
          _TestCreatorHandshakeNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final _TestCreatorHandshakeNotifier handshakeNotifier =
        container.read(creatorHandshakeProvider.notifier)
            as _TestCreatorHandshakeNotifier;
    handshakeNotifier.seed(_accountOwnedHandshakeState());
    container
        .read(creatorDraftPreviewProvider.notifier)
        .open(
          CreatorDraftPreview(
            id: 'account-a-draft',
            title: 'Account A private title',
            description: 'Account A private description',
            estimatedMinutes: 20,
            sourceOption: PlannerOptionKind.bestFit,
            createdAt: DateTime.utc(2026, 8, 30),
          ),
        );

    expect(
      container
          .read(creatorHandshakeProvider)
          .preview!
          .personContextBinding!
          .evidenceSummary,
      <String>['currentPriority: Account A private priority'],
    );
    expect(container.read(creatorDraftPreviewProvider)?.title, contains('A'));

    container.read(_accountTransitionProvider);

    expect(
      container.read(creatorHandshakeProvider).phase,
      CreatorHandshakePhase.idle,
    );
    expect(container.read(creatorHandshakeProvider).preview, isNull);
    expect(container.read(creatorDraftPreviewProvider), isNull);
  });
}

final class _TestCreatorHandshakeNotifier extends CreatorHandshakeNotifier {
  @override
  CreatorHandshakeState build() => const CreatorHandshakeState();

  void seed(CreatorHandshakeState value) => state = value;
}

CreatorHandshakeState _accountOwnedHandshakeState() {
  final DateTime createdAt = DateTime.utc(2026, 8, 30, 12);
  final CreatorTaskMutation task = CreatorTaskMutation(
    taskId: 'account-a-task',
    creatorKind: 'task',
    title: 'Account A private task',
    description: 'Account A private description',
    priority: 3,
    difficulty: 3,
    energyRequired: 3,
    createdAt: createdAt,
    scheduledFor: null,
    recurrenceRule: RecurrenceRule.none,
  );
  final CreatorMutationOperation operation = CreatorMutationOperation(
    operationId: 'account-a-create-task',
    kind: CreatorMutationKind.createTask,
    label: 'Create private task',
    task: task,
  );
  return CreatorHandshakeState(
    phase: CreatorHandshakePhase.preview,
    preview: CreatorHandshakePreview(
      proposalId: 'account-a-proposal',
      accountScopeId: 'account-a',
      source: CreatorHandshakeSource.creator,
      baseDomainRevision: 'account-a-revision',
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 5)),
      operations: <CreatorMutationOperation>[operation],
      selectedOperationIds: <String>{operation.operationId},
      personContextBinding: CreatorPersonContextBinding(
        revision: 'account-a-person-context',
        hasBoundEvidence: true,
        evidenceSummary: const <String>[
          'currentPriority: Account A private priority',
        ],
      ),
    ),
  );
}
