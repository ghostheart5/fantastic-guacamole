import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/learning/learning_ledger.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps confidence low until outcomes repeat', () {
    final DateTime now = DateTime.utc(2026, 9, 2);
    final LearningLedgerSummary summary = LearningLedgerSummary.fromOutcomes(
      <DecisionOutcomeEntity>[
        _outcome('one', now, option: 'minimum'),
        _outcome('two', now, option: 'minimum'),
      ],
      now: now,
    );

    expect(summary.patterns.single.confidence, LearnedPreferenceConfidence.low);
    expect(summary.patterns.single.canInfluenceRecommendations, isFalse);
    expect(
      summary.patterns.single.explanation,
      contains('No preference is applied'),
    );
  });

  test('decays old outcomes and groups only by surface and situation', () {
    final DateTime now = DateTime.utc(2026, 9, 2);
    final LearningLedgerSummary summary =
        LearningLedgerSummary.fromOutcomes(<DecisionOutcomeEntity>[
          _outcome('recent-1', now, option: 'minimum'),
          _outcome('recent-2', now, option: 'minimum'),
          _outcome('recent-3', now, option: 'minimum'),
          _outcome(
            'old',
            now.subtract(const Duration(days: 60)),
            option: 'stretch',
          ),
        ], now: now);

    final LearnedPreferencePattern pattern = summary.patterns.single;
    expect(pattern.observationCount, 4);
    expect(pattern.decayedWeight, closeTo(3.25, .001));
    expect(pattern.preferredOption, 'minimum');
    expect(pattern.canInfluenceRecommendations, isTrue);
  });

  test('latest correction immediately overrides the observed result', () {
    final DateTime now = DateTime.utc(2026, 9, 2);
    final DecisionOutcomeEntity rejected = _outcome(
      'decision',
      now,
      option: 'minimum',
      kind: DecisionOutcomeKind.rejected,
      helped: false,
    );
    final DecisionOutcomeEntity correction = rejected.copyWith(
      kind: DecisionOutcomeKind.corrected,
      recordedAt: now.add(const Duration(minutes: 1)),
      correction: DecisionOutcomeKind.accepted.name,
      correctedOutcomeKind: DecisionOutcomeKind.rejected.name,
      recommendationHelped: true,
    );

    final LearnedPreferencePattern pattern = LearningLedgerSummary.fromOutcomes(
      <DecisionOutcomeEntity>[rejected, correction],
      now: now.add(const Duration(minutes: 1)),
    ).patterns.single;

    expect(pattern.helpfulWeight, greaterThan(.99));
    expect(pattern.preferredOption, 'minimum');
    expect(pattern.observationCount, 1);
  });

  test('structured observation fields survive JSON round trip', () {
    final DecisionOutcomeEntity original =
        _outcome(
          'decision',
          DateTime.utc(2026, 9, 2),
          option: 'bestFit',
        ).copyWith(
          optionSizeMinutes: 20,
          deferralReason: 'Needed a smaller step.',
          completionResult: 'Completed.',
          correction: 'accepted',
          correctedOutcomeKind: 'rejected',
        );

    final DecisionOutcomeEntity restored = DecisionOutcomeEntity.fromJson(
      original.toJson(),
    );
    expect(restored.optionChosen, 'bestFit');
    expect(restored.optionSizeMinutes, 20);
    expect(restored.deferralReason, 'Needed a smaller step.');
    expect(restored.completionResult, 'Completed.');
    expect(restored.correction, 'accepted');
    expect(restored.correctedOutcomeKind, 'rejected');
    expect(restored.recommendationHelped, isTrue);
  });

  test('the displayed surface pattern changes the Planner recommendation', () {
    final DateTime now = DateTime.utc(2026, 9, 2);
    final LearningLedgerSummary summary =
        LearningLedgerSummary.fromOutcomes(<DecisionOutcomeEntity>[
          _outcome('one', now, option: 'minimum'),
          _outcome('two', now, option: 'minimum'),
          _outcome('three', now, option: 'minimum'),
        ], now: now);

    final PlannerV2Response applied = applyPlannerLearnedPreference(
      _plannerResponse(),
      summary,
    );

    expect(applied.recommendedKind, PlannerOptionKind.minimum);
    expect(applied.recommendationReason, contains('reviewable'));
  });
}

PlannerV2Response _plannerResponse() => PlannerV2Response(
  whatIHeard: 'A task needs a bounded next step.',
  mattersMost: 'Make progress without overload.',
  verifiedEvidence: const <String>['One current task is available.'],
  options: const <PlannerOption>[
    PlannerOption(
      kind: PlannerOptionKind.minimum,
      title: 'Minimum',
      description: 'Start for five minutes.',
      estimatedMinutes: 5,
      tradeoff: 'Leaves more for later.',
    ),
    PlannerOption(
      kind: PlannerOptionKind.bestFit,
      title: 'Best fit',
      description: 'Work for twenty minutes.',
      estimatedMinutes: 20,
      tradeoff: 'Uses moderate energy.',
    ),
    PlannerOption(
      kind: PlannerOptionKind.stretch,
      title: 'Stretch',
      description: 'Finish the full task.',
      estimatedMinutes: 45,
      tradeoff: 'Uses more energy.',
    ),
  ],
  recommendedKind: PlannerOptionKind.bestFit,
  recommendationReason: 'Current evidence supports a moderate step.',
  nextStep: 'Work for twenty minutes.',
  adaptationReceipt: PlannerAdaptationReceipt(
    userSetEnergy: null,
    userSelectedEmotion: null,
    adjustments: const <String>['Used current task evidence.'],
  ),
  origin: PlannerResponseOrigin.deterministic,
);

DecisionOutcomeEntity _outcome(
  String decisionId,
  DateTime at, {
  required String option,
  DecisionOutcomeKind kind = DecisionOutcomeKind.accepted,
  bool helped = true,
}) => DecisionOutcomeEntity(
  decisionId: decisionId,
  kind: kind,
  surface: 'smart_planner',
  situation: 'bounded planning choice',
  recordedAt: at,
  modelVersion: 'v1',
  recommendationConfidence: .6,
  optionChosen: option,
  recommendationHelped: helped,
);
