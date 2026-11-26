import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// The phone check found the forecast's own working words on the screen.
/// With every disclosure open and each option selected in turn, no visible
/// text uses them, in either language.
void main() {
  final List<RegExp> banned = <RegExp>[
    RegExp('feasible block', caseSensitive: false),
    RegExp('capacity window', caseSensitive: false),
    RegExp('capacity risk', caseSensitive: false),
    RegExp('tradeoff', caseSensitive: false),
    RegExp(r'\bsignals?\b', caseSensitive: false),
    RegExp(r'\((s|es)\)'),
    RegExp(r'-v\d'),
    RegExp(r'\d+/100'),
    // The same working words in Spanish.
    RegExp('bloque viable', caseSensitive: false),
    RegExp('ventana de capacidad', caseSensitive: false),
    RegExp('riesgo de capacidad', caseSensitive: false),
    RegExp('compensación', caseSensitive: false),
    RegExp(r'\bseñal(es)?\b', caseSensitive: false),
  ];

  // The live provider's option wording (trajectory_consequence_provider.dart)
  // with the harness's tasks: three options are listed at a time.
  List<TrajectoryIntervention> interventions(int days) {
    final Duration horizon = Duration(days: days);
    return <TrajectoryIntervention>[
      TrajectoryIntervention(
        id: 'maintain',
        type: TrajectoryInterventionType.maintainCourse,
        title: 'Maintain current course',
        horizon: horizon,
        description:
            'Preserve the current plan without a declared intervention.',
        assumptions: const <String>[
          'Current completion and deferral rates remain directionally similar.',
        ],
      ),
      TrajectoryIntervention(
        id: 'planner',
        type: TrajectoryInterventionType.applySmartPlanner,
        title: 'Apply Choose a step recommendation',
        horizon: horizon,
        description:
            'Protect Draft the proposal and use the feasible plan as the active schedule.',
        subjectId: 'task-a',
        proposedBlocks: <TrajectoryBlockNode>[
          TrajectoryBlockNode(
            id: 'block-a',
            taskId: 'task-a',
            start: trajectoryFixtureNow,
            end: trajectoryFixtureNow.add(const Duration(minutes: 60)),
          ),
        ],
        assumptions: const <String>[
          'The proposed TimeBlocks are accepted and attempted.',
          'Displaced work is explicitly reconciled instead of silently carried.',
        ],
      ),
      TrajectoryIntervention(
        id: 'complete-task-a',
        type: TrajectoryInterventionType.completeTask,
        title: 'Complete Draft the proposal',
        horizon: horizon,
        description:
            'Model the selected Choose a step task as completed in its feasible block.',
        subjectId: 'task-a',
        assumptions: const <String>[
          'The task is completed without creating an unmodeled commitment.',
        ],
      ),
      TrajectoryIntervention(
        id: 'delay-task-a',
        type: TrajectoryInterventionType.delayTask,
        title: 'Delay Draft the proposal by one day',
        horizon: horizon,
        description:
            'Model one day of slippage and its Schedule and goal consequences.',
        subjectId: 'task-a',
        delay: const Duration(days: 1),
        assumptions: const <String>[
          'The delayed work remains active and consumes later capacity.',
        ],
      ),
      TrajectoryIntervention(
        id: 'recover-task-b',
        type: TrajectoryInterventionType.recoverCommitment,
        title: 'Recover Prepare the review',
        horizon: horizon,
        description:
            'Apply the task-specific deadline/capacity recovery recommendation.',
        subjectId: 'task-b',
        assumptions: const <String>[
          'The first verifiable recovery checkpoint is completed.',
        ],
      ),
      TrajectoryIntervention(
        id: 'remove-task-d',
        type: TrajectoryInterventionType.reduceScope,
        title: 'Reduce lower-priority scope',
        horizon: horizon,
        description: 'Remove Tidy the inbox from the active capacity window.',
        subjectId: 'task-d',
        assumptions: const <String>[
          'The removed commitment is optional or safely deferred with consent.',
        ],
      ),
    ];
  }

  DecisionIntelligence decision() {
    final DecisionIntelligence base = futureOutcomesDecision();
    final OperatingDecisionReceipt d = base.decision;
    return DecisionIntelligence(
      snapshot: base.snapshot,
      delta: base.delta,
      decision: OperatingDecisionReceipt(
        subjectId: d.subjectId,
        recommendedAction: d.recommendedAction,
        rationale: d.rationale,
        whyItMatters:
            'It converts the strongest available signal into measurable forward movement.',
        consequenceOfDelay: d.consequenceOfDelay,
        generatedAt: d.generatedAt,
        expiresAt: d.expiresAt,
        confidence: d.confidence,
        evidence: d.evidence,
        actionIntent: d.actionIntent,
        sourceRevisions: d.sourceRevisions,
        modelVersion: d.modelVersion,
        assumptions: d.assumptions,
      ),
      acknowledgedSnapshotId: null,
    );
  }

  for (final String language in const <String>['en', 'es']) {
    for (final PredictiveEvidenceOrigin availability
        in const <PredictiveEvidenceOrigin>[
          PredictiveEvidenceOrigin.observed,
          PredictiveEvidenceOrigin.estimated,
        ]) {
      testWidgets('no working words on the screen ($language, '
          'working hours ${availability.name})', (tester) async {
        final Set<String> texts = <String>{};
        final List<TrajectoryIntervention> all = interventions(7);
        for (int start = 0; start < all.length; start += 3) {
          final List<TrajectoryIntervention> some = all
              .skip(start)
              .take(3)
              .toList();
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpFutureOutcomes(
            tester,
            locale: Locale(language),
            size: const Size(900, 9000),
            modelFor: (int days) => futureOutcomesModel(
              days: days,
              decision: decision(),
              comparison: const FutureConsequenceEngine().compare(
                baseline: futureOutcomesBaseline(
                  days: days,
                  availabilityOrigin: availability,
                ),
                generatedAt: trajectoryFixtureNow,
                interventions: <TrajectoryIntervention>[
                  for (final TrajectoryIntervention i in some)
                    TrajectoryIntervention(
                      id: i.id,
                      type: i.type,
                      title: i.title,
                      horizon: Duration(days: days),
                      description: i.description,
                      subjectId: i.subjectId,
                      delay: i.delay,
                      proposedBlocks: i.proposedBlocks,
                      assumptions: i.assumptions,
                    ),
                ],
              ),
            ),
          );
          for (final TrajectoryIntervention option in some) {
            final Finder card = find.byKey(
              ValueKey<String>('option-${option.id}'),
            );
            if (card.evaluate().isEmpty) continue;
            await tapFutureOutcomes(tester, card);
            await openAllDisclosures(tester);
            texts.addAll(futureOutcomesTexts(tester));
          }
          await openAllDisclosures(tester);
          texts.addAll(futureOutcomesTexts(tester));
        }
        expect(texts, isNotEmpty);
        final List<String> bad = <String>[
          for (final String text in texts)
            for (final RegExp word in banned)
              if (word.hasMatch(text)) '${word.pattern}: $text',
        ];
        expect(bad, isEmpty, reason: bad.join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
