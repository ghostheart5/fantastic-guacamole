import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/usecases/decision_outcome_usecases.dart';
import 'package:fantastic_guacamole/domain/usecases/apply_learning_feedback.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final decisionOutcomeRepositoryProvider = Provider<DecisionOutcomeRepository?>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  return DecisionOutcomeRepository(ref.read(sharedPrefsStoreProvider), scope);
});

final decisionOutcomesProvider = FutureProvider<List<DecisionOutcomeEntity>>((
  Ref ref,
) async {
  final DecisionOutcomeRepository? repository = ref.watch(
    decisionOutcomeRepositoryProvider,
  );
  return repository == null
      ? const <DecisionOutcomeEntity>[]
      : GetDecisionOutcomes(repository)();
});

final decisionOutcomeActionsProvider = Provider<DecisionOutcomeActions>(
  DecisionOutcomeActions.new,
);

final latestDecisionLearningChangeProvider =
    NotifierProvider<LatestDecisionLearningChange, LearningFeedbackChange?>(
      LatestDecisionLearningChange.new,
    );

class LatestDecisionLearningChange extends Notifier<LearningFeedbackChange?> {
  @override
  LearningFeedbackChange? build() => null;

  void publish(LearningFeedbackChange change) => state = change;

  void clear() => state = null;
}

class DecisionOutcomeActions {
  DecisionOutcomeActions(this._ref);

  final Ref _ref;

  Future<void> record({
    required OperatingDecisionReceipt receipt,
    required DecisionOutcomeKind kind,
    required String surface,
    String? detail,
  }) async {
    final AccountStorageScope before = _ref.read(accountStorageScopeProvider);
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (!before.isWritable || repository == null) return;
    final DecisionOutcomeEntity outcome = DecisionOutcomeEntity(
      decisionId: receipt.decisionId,
      kind: kind,
      surface: surface,
      recordedAt: DateTime.now().toUtc(),
      modelVersion: receipt.modelVersion,
      recommendationConfidence: receipt.recommendationConfidence,
      subjectId: receipt.subjectId,
      detail: detail,
    );
    await RecordDecisionOutcome(repository)(outcome);
    final LearningFeedbackChange change = await _ref
        .read(applyLearningFeedbackUseCaseProvider)
        .recordDecisionOutcome(outcome);
    _ref.read(latestDecisionLearningChangeProvider.notifier).publish(change);
    final AccountStorageScope after = _ref.read(accountStorageScopeProvider);
    if (after.v2Namespace == before.v2Namespace && after.isWritable) {
      _ref.invalidate(decisionOutcomesProvider);
    }
  }

  Future<void> correct({
    required OperatingDecisionReceipt receipt,
    required DecisionOutcomeKind originalKind,
    required DecisionOutcomeKind replacementKind,
    required String surface,
    required String reason,
  }) async {
    if (replacementKind == DecisionOutcomeKind.corrected ||
        reason.trim().isEmpty) {
      throw ArgumentError(
        'A learning correction needs a replacement and reason.',
      );
    }
    final AccountStorageScope scope = _ref.read(accountStorageScopeProvider);
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (!scope.isWritable || repository == null) return;
    final DecisionOutcomeEntity original = DecisionOutcomeEntity(
      decisionId: receipt.decisionId,
      kind: originalKind,
      surface: surface,
      recordedAt: receipt.generatedAt,
      modelVersion: receipt.modelVersion,
      recommendationConfidence: receipt.recommendationConfidence,
      subjectId: receipt.subjectId,
    );
    final LearningFeedbackChange change = await _ref
        .read(applyLearningFeedbackUseCaseProvider)
        .correctDecisionOutcome(
          original: original,
          replacement: replacementKind,
        );
    await RecordDecisionOutcome(repository)(
      DecisionOutcomeEntity(
        decisionId: receipt.decisionId,
        kind: DecisionOutcomeKind.corrected,
        surface: surface,
        recordedAt: DateTime.now().toUtc(),
        modelVersion: receipt.modelVersion,
        recommendationConfidence: receipt.recommendationConfidence,
        subjectId: receipt.subjectId,
        detail:
            '${originalKind.name}->${replacementKind.name}: ${reason.trim()}',
      ),
    );
    _ref.read(latestDecisionLearningChangeProvider.notifier).publish(change);
    _ref.invalidate(decisionOutcomesProvider);
  }
}
