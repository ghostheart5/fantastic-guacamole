import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('outcomes are account scoped, idempotent, and bounded', () async {
    final _MemoryPrefs store = _MemoryPrefs();
    final DecisionOutcomeRepository accountA = DecisionOutcomeRepository(
      store,
      AccountStorageScope.authenticated('account-a'),
      maxRecords: 2,
    );
    final DecisionOutcomeRepository accountB = DecisionOutcomeRepository(
      store,
      AccountStorageScope.authenticated('account-b'),
      maxRecords: 2,
    );

    final DecisionOutcomeEntity shown = _outcome(
      decisionId: 'decision-1',
      kind: DecisionOutcomeKind.shown,
      at: DateTime.utc(2026, 8, 18, 10),
    );
    await accountA.record(shown);
    await accountA.record(shown);
    await accountA.record(
      _outcome(
        decisionId: 'decision-1',
        kind: DecisionOutcomeKind.accepted,
        at: DateTime.utc(2026, 8, 18, 11),
      ),
    );
    await accountA.record(
      _outcome(
        decisionId: 'decision-1',
        kind: DecisionOutcomeKind.completed,
        at: DateTime.utc(2026, 8, 18, 12),
      ),
    );

    final List<DecisionOutcomeEntity> outcomesA = await accountA.load();
    expect(outcomesA, hasLength(2));
    expect(
      outcomesA.map((DecisionOutcomeEntity value) => value.kind),
      <DecisionOutcomeKind>[
        DecisionOutcomeKind.accepted,
        DecisionOutcomeKind.completed,
      ],
    );
    expect(await accountB.load(), isEmpty);
  });

  test('signed-out storage fails closed', () async {
    final DecisionOutcomeRepository repository = DecisionOutcomeRepository(
      _MemoryPrefs(),
      const AccountStorageScope.signedOut(),
    );

    await expectLater(repository.load(), throwsStateError);
  });

  test(
    'production default retains the newest 256 outcome observations',
    () async {
      final DecisionOutcomeRepository repository = DecisionOutcomeRepository(
        _MemoryPrefs(),
        AccountStorageScope.authenticated('account-a'),
      );

      for (int index = 0; index < 300; index += 1) {
        await repository.record(
          _outcome(
            decisionId: 'decision-$index',
            kind: DecisionOutcomeKind.shown,
            at: DateTime.utc(2026, 8, 18).add(Duration(minutes: index)),
          ),
        );
      }

      final List<DecisionOutcomeEntity> outcomes = await repository.load();
      expect(outcomes, hasLength(256));
      expect(outcomes.first.decisionId, 'decision-44');
    },
  );

  test('pause and removal persist across repository sessions', () async {
    final _MemoryPrefs store = _MemoryPrefs();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'account-a',
    );
    final DecisionOutcomeRepository first = DecisionOutcomeRepository(
      store,
      scope,
    );
    final DecisionOutcomeEntity outcome = _outcome(
      decisionId: 'decision-1',
      kind: DecisionOutcomeKind.accepted,
      at: DateTime.utc(2026, 8, 18),
    );
    await first.record(outcome);
    await first.setLearningPaused(true);

    final DecisionOutcomeRepository second = DecisionOutcomeRepository(
      store,
      scope,
    );
    expect(await second.isLearningPaused(), isTrue);
    expect((await second.load()).single.id, outcome.id);

    await second.remove(outcome.id);
    final DecisionOutcomeRepository third = DecisionOutcomeRepository(
      store,
      scope,
    );
    expect(await third.load(), isEmpty);
    await third.setLearningPaused(false);
    expect(await third.isLearningPaused(), isFalse);
  });
}

DecisionOutcomeEntity _outcome({
  required String decisionId,
  required DecisionOutcomeKind kind,
  required DateTime at,
}) => DecisionOutcomeEntity(
  decisionId: decisionId,
  kind: kind,
  surface: 'nexus',
  recordedAt: at,
  modelVersion: 'predictive-planning-v2',
  recommendationConfidence: .7,
  subjectId: 'task-1',
);

class _MemoryPrefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  String? load(String key) => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
