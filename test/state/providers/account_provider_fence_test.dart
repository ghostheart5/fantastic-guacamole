import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_provider_fence.dart';
import 'package:fantastic_guacamole/state/providers/creator_draft_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/domain/usecases/apply_learning_feedback.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_decision_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final Provider<void> _accountTransitionProvider = Provider<void>((Ref ref) {
  invalidateAccountOwnedProviders(ref);
});

void main() {
  test(
    'account transition clears Creator output and reloads person context',
    () async {
      final AccountStorageScope accountA = AccountStorageScope.authenticated(
        'account-a',
      );
      int personContextLoads = 0;
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(accountA),
          personContextSpineProvider.overrideWith((Ref ref) async {
            personContextLoads += 1;
            return PersonContextSpine.empty(
              accountA.v2Namespace!,
              DateTime.utc(2026, 8, 30, 12),
            );
          }),
          creatorHandshakeProvider.overrideWith(
            _TestCreatorHandshakeNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(personContextSpineProvider.future);
      expect(personContextLoads, 1);

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
      container
          .read(personContextDecisionIgnoredSignalsProvider.notifier)
          .ignoreForNow(const <String>['account-a-private-signal']);
      container
          .read(latestDecisionLearningChangeProvider.notifier)
          .publish(
            const LearningFeedbackChange(
              observationId: 'account-a-observation',
              decisionId: 'account-a-decision',
              outcomeKind: DecisionOutcomeKind.accepted,
              isCorrection: false,
              surface: 'nexus',
              subjectId: 'account-a-task',
              beforeAffinity: .5,
              afterAffinity: .6,
              summary: 'Account A private learning summary.',
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
      await container.read(personContextSpineProvider.future);

      expect(
        container.read(creatorHandshakeProvider).phase,
        CreatorHandshakePhase.idle,
      );
      expect(container.read(creatorHandshakeProvider).preview, isNull);
      expect(container.read(creatorDraftPreviewProvider), isNull);
      expect(
        container.read(personContextDecisionIgnoredSignalsProvider),
        isEmpty,
      );
      expect(container.read(latestDecisionLearningChangeProvider), isNull);
      expect(personContextLoads, 2);
    },
  );
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
