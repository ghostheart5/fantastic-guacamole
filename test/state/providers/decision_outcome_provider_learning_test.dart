import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/usecases/apply_learning_feedback.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paused learning records nothing and resumes immediately', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'learning-account',
    );
    final _MemoryPrefs prefs = _MemoryPrefs();
    final DecisionOutcomeRepository outcomes = DecisionOutcomeRepository(
      prefs,
      scope,
    );
    final _MemoryLearningRepository learning = _MemoryLearningRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(scope),
        decisionOutcomeRepositoryProvider.overrideWithValue(outcomes),
        applyLearningFeedbackUseCaseProvider.overrideWithValue(
          ApplyLearningFeedback(learning),
        ),
      ],
    );
    addTearDown(container.dispose);
    final DecisionOutcomeActions actions = container.read(
      decisionOutcomeActionsProvider,
    );

    await actions.setPaused(true);
    await actions.record(
      receipt: _receipt(),
      kind: DecisionOutcomeKind.accepted,
      surface: 'smart_planner',
      situation: 'bounded planning choice',
      optionChosen: 'minimum',
      optionSizeMinutes: 10,
      recommendationHelped: true,
    );
    expect(await outcomes.load(), isEmpty);
    expect(learning.state, isNull);

    await actions.setPaused(false);
    await actions.record(
      receipt: _receipt(),
      kind: DecisionOutcomeKind.accepted,
      surface: 'smart_planner',
      situation: 'bounded planning choice',
      optionChosen: 'minimum',
      optionSizeMinutes: 10,
      recommendationHelped: true,
    );
    expect(await outcomes.load(), hasLength(1));
    expect(learning.state?.observations, hasLength(1));
  });

  test(
    'retention, correction, and undo keep canonical learning aligned',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'learning-account',
      );
      final DecisionOutcomeRepository outcomes = DecisionOutcomeRepository(
        _MemoryPrefs(),
        scope,
        maxRecords: 2,
      );
      final _MemoryLearningRepository learning = _MemoryLearningRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(scope),
          decisionOutcomeRepositoryProvider.overrideWithValue(outcomes),
          applyLearningFeedbackUseCaseProvider.overrideWithValue(
            ApplyLearningFeedback(learning),
          ),
        ],
      );
      addTearDown(container.dispose);
      final DecisionOutcomeActions actions = container.read(
        decisionOutcomeActionsProvider,
      );
      final DateTime now = DateTime.utc(2026, 9, 2);
      for (int index = 0; index < 3; index += 1) {
        await actions.recordDirect(
          decisionId: 'decision-$index',
          kind: DecisionOutcomeKind.rejected,
          surface: 'smart_planner',
          modelVersion: 'decision-v1',
          recommendationConfidence: .6,
          subjectId: 'task-1',
          recordedAt: now.add(Duration(minutes: index)),
        );
      }
      expect(await outcomes.load(), hasLength(2));
      expect(learning.state!.observations, hasLength(2));
      expect(
        learning.state!.observations.map((value) => value.id).join(' '),
        isNot(contains('decision-0')),
      );

      final DecisionOutcomeEntity original = (await outcomes.load()).last;
      await actions.correctOutcome(
        original: original,
        replacementKind: DecisionOutcomeKind.accepted,
        reason: 'The user corrected it.',
      );
      final DecisionOutcomeEntity correction = (await outcomes.load())
          .singleWhere(
            (DecisionOutcomeEntity value) =>
                value.kind == DecisionOutcomeKind.corrected,
          );
      expect(correction.correctedOutcomeKind, original.kind.name);
      expect(correction.correction, DecisionOutcomeKind.accepted.name);

      await actions.remove(correction);
      expect(
        learning.state!.observations
            .singleWhere((value) => value.id.contains(original.decisionId))
            .type
            .name,
        contains('Rejected'),
      );
    },
  );

  test(
    'overlapping writes are serialized without losing observations',
    () async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'learning-account',
      );
      final DecisionOutcomeRepository outcomes = DecisionOutcomeRepository(
        _MemoryPrefs(),
        scope,
      );
      final _MemoryLearningRepository learning = _MemoryLearningRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(scope),
          decisionOutcomeRepositoryProvider.overrideWithValue(outcomes),
          applyLearningFeedbackUseCaseProvider.overrideWithValue(
            ApplyLearningFeedback(learning),
          ),
        ],
      );
      addTearDown(container.dispose);
      final DecisionOutcomeActions actions = container.read(
        decisionOutcomeActionsProvider,
      );

      await Future.wait(<Future<void>>[
        for (int index = 0; index < 6; index += 1)
          actions.recordDirect(
            decisionId: 'parallel-$index',
            kind: DecisionOutcomeKind.accepted,
            surface: 'smart_planner',
            situation: 'bounded planning choice',
            optionChosen: 'minimum',
            modelVersion: 'decision-v1',
            recommendationConfidence: .6,
            subjectId: 'task-$index',
          ),
      ]);

      expect(await outcomes.load(), hasLength(6));
      expect(learning.state!.observations, hasLength(6));
    },
  );

  test('corrections target each original kind independently', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'learning-account',
    );
    final DecisionOutcomeRepository outcomes = DecisionOutcomeRepository(
      _MemoryPrefs(),
      scope,
    );
    final _MemoryLearningRepository learning = _MemoryLearningRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(scope),
        decisionOutcomeRepositoryProvider.overrideWithValue(outcomes),
        applyLearningFeedbackUseCaseProvider.overrideWithValue(
          ApplyLearningFeedback(learning),
        ),
      ],
    );
    addTearDown(container.dispose);
    final DecisionOutcomeActions actions = container.read(
      decisionOutcomeActionsProvider,
    );
    final DateTime now = DateTime.utc(2026, 9, 2);
    final DecisionOutcomeEntity accepted = _outcomeForKind(
      DecisionOutcomeKind.accepted,
      now,
    );
    final DecisionOutcomeEntity completed = _outcomeForKind(
      DecisionOutcomeKind.completed,
      now.add(const Duration(minutes: 1)),
    );
    await actions.recordDirect(
      decisionId: accepted.decisionId,
      kind: accepted.kind,
      surface: accepted.surface,
      modelVersion: accepted.modelVersion,
      recommendationConfidence: accepted.recommendationConfidence,
      subjectId: accepted.subjectId,
      recordedAt: accepted.recordedAt,
    );
    await actions.recordDirect(
      decisionId: completed.decisionId,
      kind: completed.kind,
      surface: completed.surface,
      modelVersion: completed.modelVersion,
      recommendationConfidence: completed.recommendationConfidence,
      subjectId: completed.subjectId,
      recordedAt: completed.recordedAt,
    );
    await actions.correctOutcome(
      original: accepted,
      replacementKind: DecisionOutcomeKind.rejected,
      reason: 'Accepted was wrong.',
    );
    await actions.correctOutcome(
      original: completed,
      replacementKind: DecisionOutcomeKind.skipped,
      reason: 'Completed was wrong.',
    );

    final List<DecisionOutcomeEntity> corrections = (await outcomes.load())
        .where((value) => value.kind == DecisionOutcomeKind.corrected)
        .toList();
    expect(corrections, hasLength(2));
    expect(
      corrections.map((value) => value.correctedOutcomeKind).toSet(),
      <String>{'accepted', 'completed'},
    );
    await actions.remove(
      corrections.singleWhere(
        (value) => value.correctedOutcomeKind == 'accepted',
      ),
    );
    expect(
      (await outcomes.load())
          .where((value) => value.kind == DecisionOutcomeKind.corrected)
          .single
          .correctedOutcomeKind,
      'completed',
    );
  });

  test('delete all removes learning already evicted from the ledger', () async {
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'learning-account',
    );
    final DecisionOutcomeRepository outcomes = DecisionOutcomeRepository(
      _MemoryPrefs(),
      scope,
      maxRecords: 1,
    );
    final _MemoryLearningRepository learning = _MemoryLearningRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(scope),
        decisionOutcomeRepositoryProvider.overrideWithValue(outcomes),
        applyLearningFeedbackUseCaseProvider.overrideWithValue(
          ApplyLearningFeedback(learning),
        ),
      ],
    );
    addTearDown(container.dispose);
    final DecisionOutcomeActions actions = container.read(
      decisionOutcomeActionsProvider,
    );
    await actions.recordDirect(
      decisionId: 'canonical-but-evicted',
      kind: DecisionOutcomeKind.accepted,
      surface: 'smart_planner',
      modelVersion: 'decision-v1',
      recommendationConfidence: .6,
      subjectId: 'task-1',
    );
    await outcomes.record(
      DecisionOutcomeEntity(
        decisionId: 'direct-evictor',
        kind: DecisionOutcomeKind.completed,
        surface: 'daily-rhythm',
        recordedAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
        modelVersion: 'domain-occurrence-v1',
        recommendationConfidence: 1,
      ),
    );
    expect(learning.state!.observations, hasLength(1));

    await actions.clear();

    expect(await outcomes.load(), isEmpty);
    expect(learning.state!.observations, isEmpty);
  });

  test('queued decision work is discarded after an account transition', () async {
    final _MemoryPrefs prefs = _MemoryPrefs();
    final Map<String, DecisionOutcomeRepository> outcomes =
        <String, DecisionOutcomeRepository>{
          'account-a': DecisionOutcomeRepository(
            prefs,
            AccountStorageScope.authenticated('account-a'),
          ),
          'account-b': DecisionOutcomeRepository(
            prefs,
            AccountStorageScope.authenticated('account-b'),
          ),
        };
    final Map<String, _MemoryLearningRepository> learning =
        <String, _MemoryLearningRepository>{
          'account-a': _MemoryLearningRepository(),
          'account-b': _MemoryLearningRepository(),
        };
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => ref.watch(_mutableDecisionScopeProvider),
        ),
        decisionOutcomeRepositoryProvider.overrideWith((Ref ref) {
          final String accountId =
              ref.watch(accountStorageScopeProvider).rawUserId!;
          return outcomes[accountId];
        }),
        applyLearningFeedbackUseCaseProvider.overrideWith((Ref ref) {
          final String accountId =
              ref.watch(accountStorageScopeProvider).rawUserId!;
          return ApplyLearningFeedback(learning[accountId]!);
        }),
      ],
    );
    addTearDown(container.dispose);
    final DecisionOutcomeActions actions = container.read(
      decisionOutcomeActionsProvider,
    );

    final Future<void> queued = actions.recordDirect(
      decisionId: 'queued-under-a',
      kind: DecisionOutcomeKind.accepted,
      surface: 'smart_planner',
      modelVersion: 'decision-v1',
      recommendationConfidence: .6,
    );
    container.read(_mutableDecisionScopeProvider.notifier).switchTo('account-b');
    await queued;

    expect(await outcomes['account-a']!.load(), isEmpty);
    expect(await outcomes['account-b']!.load(), isEmpty);
    expect(learning['account-a']!.state, isNull);
    expect(learning['account-b']!.state, isNull);
  });
}

DecisionOutcomeEntity _outcomeForKind(
  DecisionOutcomeKind kind,
  DateTime recordedAt,
) => DecisionOutcomeEntity(
  decisionId: 'multi-kind-decision',
  kind: kind,
  surface: 'nexus',
  recordedAt: recordedAt,
  modelVersion: 'decision-v1',
  recommendationConfidence: .6,
  subjectId: 'task-1',
);

OperatingDecisionReceipt _receipt() {
  final DateTime generatedAt = DateTime.now().toUtc();
  return OperatingDecisionReceipt(
    decisionId: 'decision-learning',
    subjectId: 'task-1',
    recommendedAction: 'Start the minimum option',
    rationale: 'It fits the available time.',
    whyItMatters: 'It creates progress.',
    consequenceOfDelay: 'The task remains open.',
    generatedAt: generatedAt,
    expiresAt: generatedAt.add(const Duration(hours: 1)),
    confidence: OperatingConfidence.moderate,
    evidence: <OperatingEvidence>[
      OperatingEvidence(
        code: 'task',
        description: 'A current task is available.',
        kind: OperatingEvidenceKind.observed,
        recordedAt: generatedAt,
        source: 'tasks',
        subjectId: 'task-1',
      ),
    ],
    actionIntent: const OperatingActionIntent(
      id: 'review',
      type: OperatingActionType.openSmartPlanner,
      label: 'Review task',
      destination: '/planner',
      targetEntityId: 'task-1',
    ),
    sourceRevisions: const <String, String>{'tasks': '1'},
    modelVersion: 'decision-v1',
  );
}

class _MemoryLearningRepository implements ILearningRepository {
  LearningEntity? state;

  @override
  Future<LearningEntity?> getState() async => state;

  @override
  Future<void> saveState(LearningEntity state) async => this.state = state;
}

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

final NotifierProvider<_MutableDecisionScope, AccountStorageScope>
_mutableDecisionScopeProvider =
    NotifierProvider<_MutableDecisionScope, AccountStorageScope>(
      _MutableDecisionScope.new,
    );

final class _MutableDecisionScope extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('account-a');

  void switchTo(String accountId) {
    state = AccountStorageScope.authenticated(accountId);
  }
}
