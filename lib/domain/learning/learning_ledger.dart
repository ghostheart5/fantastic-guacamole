// CHRONOSPARK-CLASS: SHIPPING | Feature: reviewable outcome learning ledger
import 'dart:math' as math;

import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';

enum LearnedPreferenceConfidence { low, developing, established }

/// A bounded, explainable summary of observed outcomes. This is a preference
/// signal, never a fact about the person or an identity/profile attribute.
class LearnedPreferencePattern {
  const LearnedPreferencePattern({
    required this.surface,
    required this.situation,
    required this.observationCount,
    required this.decayedWeight,
    required this.helpfulWeight,
    required this.confidence,
    this.preferredOption,
  });

  final String surface;
  final String situation;
  final int observationCount;
  final double decayedWeight;
  final double helpfulWeight;
  final LearnedPreferenceConfidence confidence;
  final String? preferredOption;

  bool get canInfluenceRecommendations =>
      observationCount >= 3 && decayedWeight >= 1.5;

  String get explanation {
    if (!canInfluenceRecommendations) {
      return 'Still learning: $observationCount reviewable outcome${observationCount == 1 ? '' : 's'}. No preference is applied yet.';
    }
    final int helpfulPercent = decayedWeight == 0
        ? 0
        : ((helpfulWeight / decayedWeight).clamp(0.0, 1.0) * 100).round();
    final String option = preferredOption == null
        ? ''
        : ' The strongest repeated option is $preferredOption.';
    return '$helpfulPercent% of recent weighted outcomes helped.$option';
  }
}

class LearningLedgerSummary {
  const LearningLedgerSummary({
    required this.patterns,
    required this.generatedAt,
  });

  final List<LearnedPreferencePattern> patterns;
  final DateTime generatedAt;

  static const Duration halfLife = Duration(days: 30);

  factory LearningLedgerSummary.fromOutcomes(
    List<DecisionOutcomeEntity> outcomes, {
    DateTime? now,
  }) {
    final DateTime reference = (now ?? DateTime.now()).toUtc();
    final Map<String, _PatternAccumulator> grouped =
        <String, _PatternAccumulator>{};
    final Map<String, DecisionOutcomeKind> corrections =
        <String, DecisionOutcomeKind>{};
    for (final DecisionOutcomeEntity outcome in outcomes) {
      if (outcome.kind != DecisionOutcomeKind.corrected) continue;
      final String? replacement = outcome.correction;
      final String? originalKind = outcome.correctedOutcomeKind;
      if (replacement == null || originalKind == null) continue;
      corrections['${outcome.decisionId}\u0000${outcome.surface}\u0000$originalKind'] =
          DecisionOutcomeKind.values.firstWhere(
            (DecisionOutcomeKind value) => value.name == replacement,
            orElse: () => DecisionOutcomeKind.corrected,
          );
    }
    for (final DecisionOutcomeEntity storedOutcome in outcomes) {
      if (storedOutcome.kind == DecisionOutcomeKind.corrected) continue;
      final DecisionOutcomeKind? correction =
          corrections['${storedOutcome.decisionId}\u0000${storedOutcome.surface}\u0000${storedOutcome.kind.name}'];
      final DecisionOutcomeEntity outcome =
          correction == null || correction == DecisionOutcomeKind.corrected
          ? storedOutcome
          : storedOutcome.copyWith(
              kind: correction,
              recommendationHelped:
                  correction == DecisionOutcomeKind.accepted ||
                  correction == DecisionOutcomeKind.completed,
            );
      if (outcome.kind == DecisionOutcomeKind.shown ||
          outcome.kind == DecisionOutcomeKind.corrected) {
        continue;
      }
      final String situation = _normalizedSituation(outcome);
      final String key = '${outcome.surface}\u0000$situation';
      final _PatternAccumulator accumulator = grouped.putIfAbsent(
        key,
        () => _PatternAccumulator(outcome.surface, situation),
      );
      final int ageSeconds = math.max(
        0,
        reference.difference(outcome.recordedAt.toUtc()).inSeconds,
      );
      final double weight = math
          .pow(.5, ageSeconds / halfLife.inSeconds)
          .toDouble();
      accumulator.add(outcome, weight);
    }

    final List<LearnedPreferencePattern> patterns =
        grouped.values
            .map((_PatternAccumulator value) => value.build())
            .toList(growable: false)
          ..sort(
            (LearnedPreferencePattern first, LearnedPreferencePattern second) =>
                second.decayedWeight.compareTo(first.decayedWeight),
          );
    return LearningLedgerSummary(
      patterns: List<LearnedPreferencePattern>.unmodifiable(patterns),
      generatedAt: reference,
    );
  }

  LearnedPreferencePattern? patternFor({
    required String surface,
    required String situation,
  }) {
    for (final LearnedPreferencePattern pattern in patterns) {
      if (pattern.surface == surface && pattern.situation == situation) {
        return pattern;
      }
    }
    return null;
  }
}

/// Applies only the same reviewable surface/situation aggregate shown in the
/// learning ledger. Low-confidence and unrecognized preferences are ignored.
PlannerV2Response applyPlannerLearnedPreference(
  PlannerV2Response response,
  LearningLedgerSummary summary,
) {
  if (response.isClarification) return response;
  final LearnedPreferencePattern? pattern = summary.patternFor(
    surface: 'smart_planner',
    situation: 'bounded planning choice',
  );
  if (pattern == null || !pattern.canInfluenceRecommendations) return response;
  PlannerOptionKind? preferred;
  for (final PlannerOptionKind value in PlannerOptionKind.values) {
    if (value.name == pattern.preferredOption) preferred = value;
  }
  if (preferred == null) return response;
  return response.recommend(
    preferred,
    why:
        'Your reviewable Smart Planner feedback repeatedly favored the ${preferred.name} option. You can choose another option or correct this learning at any time.',
  );
}

String _normalizedSituation(DecisionOutcomeEntity outcome) {
  final String? explicit = outcome.situation?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  return outcome.subjectId == null ? 'general guidance' : 'task guidance';
}

class _PatternAccumulator {
  _PatternAccumulator(this.surface, this.situation);

  final String surface;
  final String situation;
  int count = 0;
  double weight = 0;
  double helpful = 0;
  final Map<String, double> optionScores = <String, double>{};

  void add(DecisionOutcomeEntity outcome, double decayedWeight) {
    count += 1;
    weight += decayedWeight;
    final bool positive =
        outcome.recommendationHelped == true ||
        outcome.kind == DecisionOutcomeKind.accepted ||
        outcome.kind == DecisionOutcomeKind.completed;
    final bool negative =
        outcome.recommendationHelped == false ||
        outcome.kind == DecisionOutcomeKind.rejected ||
        outcome.kind == DecisionOutcomeKind.skipped;
    if (positive) helpful += decayedWeight;
    final String? option = outcome.optionChosen?.trim();
    if (option != null && option.isNotEmpty) {
      optionScores.update(
        option,
        (double value) => value + (negative ? -decayedWeight : decayedWeight),
        ifAbsent: () => negative ? -decayedWeight : decayedWeight,
      );
    }
  }

  LearnedPreferencePattern build() {
    final List<MapEntry<String, double>> options = optionScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final LearnedPreferenceConfidence confidence = count < 3 || weight < 1.5
        ? LearnedPreferenceConfidence.low
        : count < 6 || weight < 3.5
        ? LearnedPreferenceConfidence.developing
        : LearnedPreferenceConfidence.established;
    return LearnedPreferencePattern(
      surface: surface,
      situation: situation,
      observationCount: count,
      decayedWeight: weight,
      helpfulWeight: helpful,
      confidence: confidence,
      preferredOption: options.isEmpty || options.first.value <= 0
          ? null
          : options.first.key,
    );
  }
}
