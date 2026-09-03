import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/learning/learning_ledger.dart';
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

final learningRevisionProvider = NotifierProvider<LearningRevision, int>(
  LearningRevision.new,
);

class LearningRevision extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state += 1;
}

final learningPausedProvider = FutureProvider<bool>((Ref ref) async {
  final DecisionOutcomeRepository? repository = ref.watch(
    decisionOutcomeRepositoryProvider,
  );
  return repository == null ? true : repository.isLearningPaused();
});

final learningLedgerSummaryProvider = Provider<LearningLedgerSummary>((
  Ref ref,
) {
  final List<DecisionOutcomeEntity> outcomes =
      ref.watch(decisionOutcomesProvider).asData?.value ??
      const <DecisionOutcomeEntity>[];
  return LearningLedgerSummary.fromOutcomes(outcomes);
});

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
  Future<void> _tail = Future<void>.value();

  Future<void> record({
    required OperatingDecisionReceipt receipt,
    required DecisionOutcomeKind kind,
    required String surface,
    String? detail,
    String? situation,
    String? optionChosen,
    int? optionSizeMinutes,
    String? deferralReason,
    String? completionResult,
    bool? recommendationHelped,
  }) {
    return recordDirect(
      decisionId: receipt.decisionId,
      kind: kind,
      surface: surface,
      modelVersion: receipt.modelVersion,
      recommendationConfidence: receipt.recommendationConfidence,
      subjectId: receipt.subjectId,
      detail: detail,
      situation: situation,
      optionChosen: optionChosen,
      optionSizeMinutes: optionSizeMinutes,
      deferralReason: deferralReason,
      completionResult: completionResult,
      recommendationHelped: recommendationHelped,
    );
  }

  Future<void> recordDirect({
    required String decisionId,
    required DecisionOutcomeKind kind,
    required String surface,
    required String modelVersion,
    required double recommendationConfidence,
    String? subjectId,
    String? detail,
    String? situation,
    String? optionChosen,
    int? optionSizeMinutes,
    String? deferralReason,
    String? completionResult,
    bool? recommendationHelped,
    DateTime? recordedAt,
  }) {
    return _enqueue(
      () => _recordDirectImpl(
        decisionId: decisionId,
        kind: kind,
        surface: surface,
        modelVersion: modelVersion,
        recommendationConfidence: recommendationConfidence,
        subjectId: subjectId,
        detail: detail,
        situation: situation,
        optionChosen: optionChosen,
        optionSizeMinutes: optionSizeMinutes,
        deferralReason: deferralReason,
        completionResult: completionResult,
        recommendationHelped: recommendationHelped,
        recordedAt: recordedAt,
      ),
    );
  }

  Future<void> _recordDirectImpl({
    required String decisionId,
    required DecisionOutcomeKind kind,
    required String surface,
    required String modelVersion,
    required double recommendationConfidence,
    String? subjectId,
    String? detail,
    String? situation,
    String? optionChosen,
    int? optionSizeMinutes,
    String? deferralReason,
    String? completionResult,
    bool? recommendationHelped,
    DateTime? recordedAt,
  }) async {
    final AccountStorageScope before = _ref.read(accountStorageScopeProvider);
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (!before.isWritable || repository == null) return;
    if (await repository.isLearningPaused()) return;
    final DecisionOutcomeEntity outcome = DecisionOutcomeEntity(
      decisionId: decisionId,
      kind: kind,
      surface: surface,
      recordedAt: (recordedAt ?? DateTime.now()).toUtc(),
      modelVersion: modelVersion,
      recommendationConfidence: recommendationConfidence,
      subjectId: subjectId,
      detail: detail,
      situation: situation,
      optionChosen: optionChosen,
      optionSizeMinutes: optionSizeMinutes,
      deferralReason: deferralReason,
      completionResult: completionResult,
      recommendationHelped: recommendationHelped,
    );
    await RecordDecisionOutcome(repository)(outcome);
    final ApplyLearningFeedback learning = _ref.read(
      applyLearningFeedbackUseCaseProvider,
    );
    final LearningFeedbackChange change = await learning.recordDecisionOutcome(
      outcome,
    );
    await learning.retainDecisionOutcomes(await repository.load());
    _ref.read(latestDecisionLearningChangeProvider.notifier).publish(change);
    final AccountStorageScope after = _ref.read(accountStorageScopeProvider);
    if (after.v2Namespace == before.v2Namespace && after.isWritable) {
      _ref.invalidate(decisionOutcomesProvider);
      _advanceLearningRevision();
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
    await correctOutcome(
      original: original,
      replacementKind: replacementKind,
      reason: reason,
    );
  }

  Future<void> correctOutcome({
    required DecisionOutcomeEntity original,
    required DecisionOutcomeKind replacementKind,
    required String reason,
  }) => _enqueue(
    () => _correctOutcomeImpl(
      original: original,
      replacementKind: replacementKind,
      reason: reason,
    ),
  );

  Future<void> _correctOutcomeImpl({
    required DecisionOutcomeEntity original,
    required DecisionOutcomeKind replacementKind,
    required String reason,
  }) async {
    if (replacementKind == DecisionOutcomeKind.corrected ||
        reason.trim().isEmpty) {
      throw ArgumentError(
        'A learning correction needs a replacement and reason.',
      );
    }
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (repository == null) return;
    final LearningFeedbackChange change = await _ref
        .read(applyLearningFeedbackUseCaseProvider)
        .correctDecisionOutcome(
          original: original,
          replacement: replacementKind,
        );
    await RecordDecisionOutcome(repository)(
      DecisionOutcomeEntity(
        decisionId: original.decisionId,
        kind: DecisionOutcomeKind.corrected,
        surface: original.surface,
        recordedAt: DateTime.now().toUtc(),
        modelVersion: original.modelVersion,
        recommendationConfidence: original.recommendationConfidence,
        subjectId: original.subjectId,
        detail:
            '${original.kind.name}->${replacementKind.name}: ${reason.trim()}',
        correction: replacementKind.name,
        correctedOutcomeKind: original.kind.name,
        recommendationHelped:
            replacementKind == DecisionOutcomeKind.accepted ||
            replacementKind == DecisionOutcomeKind.completed,
      ),
    );
    await _ref
        .read(applyLearningFeedbackUseCaseProvider)
        .retainDecisionOutcomes(await repository.load());
    _ref.read(latestDecisionLearningChangeProvider.notifier).publish(change);
    _ref.invalidate(decisionOutcomesProvider);
    _advanceLearningRevision();
  }

  Future<void> setPaused(bool paused) => _enqueue(() async {
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (repository == null) return;
    await repository.setLearningPaused(paused);
    _ref.invalidate(learningPausedProvider);
    _advanceLearningRevision();
  });

  Future<void> remove(DecisionOutcomeEntity outcome) =>
      _enqueue(() => _removeImpl(outcome));

  Future<void> _removeImpl(DecisionOutcomeEntity outcome) async {
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (repository == null) return;
    final List<DecisionOutcomeEntity> current = await repository.load();
    final ApplyLearningFeedback learning = _ref.read(
      applyLearningFeedbackUseCaseProvider,
    );
    if (outcome.kind == DecisionOutcomeKind.corrected) {
      await repository.remove(outcome.id);
      final List<DecisionOutcomeEntity> originals = current
          .where(
            (DecisionOutcomeEntity value) =>
                value.decisionId == outcome.decisionId &&
                value.surface == outcome.surface &&
                value.kind.name == outcome.correctedOutcomeKind &&
                value.kind != DecisionOutcomeKind.corrected &&
                value.kind != DecisionOutcomeKind.shown,
          )
          .toList(growable: false);
      if (originals.isNotEmpty) {
        await learning.correctDecisionOutcome(
          original: originals.last,
          replacement: originals.last.kind,
        );
      }
    } else {
      final List<DecisionOutcomeEntity> linked = current
          .where(
            (DecisionOutcomeEntity value) =>
                value.id == outcome.id ||
                (value.kind == DecisionOutcomeKind.corrected &&
                    value.decisionId == outcome.decisionId &&
                    value.surface == outcome.surface &&
                    value.correctedOutcomeKind == outcome.kind.name),
          )
          .toList(growable: false);
      await repository.replaceSnapshot(
        current
            .where(
              (DecisionOutcomeEntity value) => !linked.any(
                (DecisionOutcomeEntity removed) => removed.id == value.id,
              ),
            )
            .toList(growable: false),
      );
      await learning.removeDecisionOutcomes(<DecisionOutcomeEntity>[outcome]);
    }
    _ref.invalidate(decisionOutcomesProvider);
    _advanceLearningRevision();
  }

  Future<void> clear() => _enqueue(_clearImpl);

  Future<void> _clearImpl() async {
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (repository == null) return;
    await repository.clear();
    await _ref
        .read(applyLearningFeedbackUseCaseProvider)
        .retainDecisionOutcomes(const <DecisionOutcomeEntity>[]);
    _ref.invalidate(decisionOutcomesProvider);
    _advanceLearningRevision();
  }

  void _advanceLearningRevision() {
    _ref.read(learningRevisionProvider.notifier).advance();
    _ref.invalidate(domainSiDecisionProvider);
  }

  Future<void> reconcileRetention() => _enqueue(() async {
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (repository == null) return;
    await _ref
        .read(applyLearningFeedbackUseCaseProvider)
        .retainDecisionOutcomes(await repository.load());
    _ref.invalidate(decisionOutcomesProvider);
    _advanceLearningRevision();
  });

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> result = _tail.then((_) => operation());
    _tail = result.catchError((Object _) {});
    return result;
  }

  String exportJson(
    List<DecisionOutcomeEntity> outcomes,
  ) => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'schemaVersion': 1,
    'description':
        'Reviewable decision outcomes used only for bounded preference learning.',
    'outcomes': outcomes
        .map((DecisionOutcomeEntity outcome) => outcome.toJson())
        .toList(growable: false),
  });
}
