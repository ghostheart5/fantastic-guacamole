import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_observation_entity.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/policies/learning_policy.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Learning/adaptation
///
/// Registered as applyLearningFeedbackUseCaseProvider. Repository is real; not
/// yet auto-invoked from completion/skip.
class ApplyLearningFeedback {
  ApplyLearningFeedback(this.repository, {this.siRepo});

  final ILearningRepository repository;
  final ISiRepository? siRepo;

  Future<LearningEntity> call({
    required bool success,
    required int difficulty,
    String? taskId,
    String source = 'learning_feedback',
    DateTime? now,
  }) async {
    final LearningEntity current =
        await repository.getState() ?? LearningEntity();
    final LearningEntity weighted = LearningPolicy.applyFeedback(
      current: current,
      success: success,
      difficulty: difficulty,
    );
    final DateTime observedAt = (now ?? DateTime.now()).toUtc();
    final LearningEntity updated = weighted.recordObservation(
      DecisionObservationEntity(
        id: '$source-${observedAt.microsecondsSinceEpoch}',
        type: success
            ? DecisionObservationType.taskCompleted
            : DecisionObservationType.taskSkipped,
        timestamp: observedAt,
        source: source,
        taskId: taskId,
      ),
    );
    await repository.saveState(updated);

    final ISiRepository? si = siRepo;
    if (si != null && success) {
      final siState = await si.getCurrentState();
      if (siState != null) {
        await si.saveState(siState.withConfidenceDelta(0.02));
      }
    }

    return updated;
  }

  Future<LearningFeedbackChange> recordDecisionOutcome(
    DecisionOutcomeEntity outcome,
  ) async {
    final LearningEntity current =
        await repository.getState() ?? LearningEntity();
    final String observationId = _observationId(outcome);
    final double before = outcome.subjectId == null
        ? .5
        : current.taskAffinity[outcome.subjectId] ?? .5;
    final LearningEntity updated = current.recordObservation(
      DecisionObservationEntity(
        id: observationId,
        type: _observationType(outcome.kind),
        timestamp: outcome.recordedAt.toUtc(),
        source: 'decision_outcome:${outcome.surface}',
        taskId: outcome.subjectId,
      ),
    );
    await repository.saveState(updated);
    final double after = outcome.subjectId == null
        ? before
        : updated.taskAffinity[outcome.subjectId] ?? before;
    return LearningFeedbackChange(
      observationId: observationId,
      decisionId: outcome.decisionId,
      outcomeKind: outcome.kind,
      isCorrection: false,
      surface: outcome.surface,
      subjectId: outcome.subjectId,
      beforeAffinity: before,
      afterAffinity: after,
      summary: _changeSummary(outcome.kind, before, after),
    );
  }

  Future<LearningFeedbackChange> correctDecisionOutcome({
    required DecisionOutcomeEntity original,
    required DecisionOutcomeKind replacement,
    DateTime? correctedAt,
  }) async {
    final LearningEntity current =
        await repository.getState() ?? LearningEntity();
    final double before = original.subjectId == null
        ? .5
        : current.taskAffinity[original.subjectId] ?? .5;
    final LearningEntity updated = current.correctObservation(
      observationId: _observationId(original),
      replacement: _observationType(replacement),
      correctedAt: correctedAt ?? DateTime.now().toUtc(),
    );
    await repository.saveState(updated);
    final double after = original.subjectId == null
        ? before
        : updated.taskAffinity[original.subjectId] ?? before;
    return LearningFeedbackChange(
      observationId: _observationId(original),
      decisionId: original.decisionId,
      outcomeKind: original.kind,
      isCorrection: true,
      surface: original.surface,
      subjectId: original.subjectId,
      beforeAffinity: before,
      afterAffinity: after,
      summary:
          'Learning was corrected from ${original.kind.name} to ${replacement.name}.',
    );
  }
}

class LearningFeedbackChange {
  const LearningFeedbackChange({
    required this.observationId,
    required this.decisionId,
    required this.outcomeKind,
    required this.isCorrection,
    required this.surface,
    required this.subjectId,
    required this.beforeAffinity,
    required this.afterAffinity,
    required this.summary,
  });

  final String observationId;
  final String decisionId;
  final DecisionOutcomeKind outcomeKind;
  final bool isCorrection;
  final String surface;
  final String? subjectId;
  final double beforeAffinity;
  final double afterAffinity;
  final String summary;

  bool get changed => beforeAffinity != afterAffinity;
}

String _observationId(DecisionOutcomeEntity outcome) =>
    'decision-outcome:${outcome.id}';

DecisionObservationType _observationType(DecisionOutcomeKind kind) =>
    switch (kind) {
      DecisionOutcomeKind.shown => DecisionObservationType.recommendationShown,
      DecisionOutcomeKind.accepted =>
        DecisionObservationType.recommendationAccepted,
      DecisionOutcomeKind.rejected =>
        DecisionObservationType.recommendationRejected,
      DecisionOutcomeKind.corrected =>
        DecisionObservationType.recommendationCorrected,
      DecisionOutcomeKind.completed => DecisionObservationType.taskCompleted,
      DecisionOutcomeKind.skipped => DecisionObservationType.taskSkipped,
      DecisionOutcomeKind.deferred => DecisionObservationType.taskRescheduled,
    };

String _changeSummary(DecisionOutcomeKind kind, double before, double after) {
  if (before == after) {
    return 'The ${kind.name} outcome was recorded; ranking weights did not change.';
  }
  final String direction = after > before ? 'increased' : 'decreased';
  return 'This task\'s learned fit $direction from ${(before * 100).round()}% to ${(after * 100).round()}% after the ${kind.name} outcome.';
}
