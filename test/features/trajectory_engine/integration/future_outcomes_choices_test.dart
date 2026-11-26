import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// Habit lines beside the forecast, the selected option kept by its kind,
/// and the reason when options show the same workload.
void main() {
  String textsIn(WidgetTester tester, Finder of) => tester
      .widgetList<Text>(find.descendant(of: of, matching: find.byType(Text)))
      .map((Text t) => t.data ?? '')
      .join(' | ');

  final Finder habits = find.byKey(const Key('keep-going-habits'));
  final Finder selectedCard = find.byKey(const Key('future-outcomes-selected'));

  group('habit lines', () {
    testWidgets('loading shows a quiet waiting line, never "no habits"', (
      tester,
    ) async {
      await pumpFutureOutcomes(
        tester,
        habitsFor: (int days) => TrajectoryHabitLines(
          status: TrajectoryHabitLinesStatus.loading,
          horizonDays: days,
        ),
      );
      expect(
        find.descendant(
          of: habits,
          matching: find.text('Checking your habits…'),
        ),
        findsOneWidget,
      );
      expect(find.text('No active habits.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final String language in const <String>['en', 'es']) {
      testWidgets('unavailable shows a neutral line ($language)', (
        tester,
      ) async {
        await pumpFutureOutcomes(
          tester,
          locale: Locale(language),
          habitsFor: (int days) => TrajectoryHabitLines(
            status: TrajectoryHabitLinesStatus.unavailable,
            horizonDays: days,
          ),
        );
        expect(
          find.descendant(
            of: habits,
            matching: find.text(
              language == 'es'
                  ? 'Los hábitos no están disponibles ahora.'
                  : "Habits aren't available right now.",
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ready with no habits says so briefly', (tester) async {
      await pumpFutureOutcomes(
        tester,
        habitsFor: (int days) => TrajectoryHabitLines(
          status: TrajectoryHabitLinesStatus.ready,
          horizonDays: days,
        ),
      );
      expect(
        find.descendant(of: habits, matching: find.text('No active habits.')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final String language in const <String>['en', 'es']) {
      testWidgets('ready lines: one row per habit, estimates and history '
          '($language)', (tester) async {
        final bool es = language == 'es';
        await pumpFutureOutcomes(tester, locale: Locale(language));
        final String walk = textsIn(
          tester,
          find.byKey(const ValueKey<String>('habit-line-habit-walk')),
        );
        expect(walk, contains('Morning walk'));
        expect(
          walk,
          contains(es ? 'unos 5 de 7 registros' : 'about 5 of 7 check-ins'),
        );
        expect(
          walk,
          contains(
            es
                ? 'Probablemente de 4 a 6. Es una estimación.'
                : 'Likely 4 to 6. This is an estimate.',
          ),
        );
        final String read = textsIn(
          tester,
          find.byKey(const ValueKey<String>('habit-line-habit-read')),
        );
        expect(read, contains('Read a chapter'));
        expect(
          read,
          contains(es ? 'Necesita más historial' : 'Needs more history'),
        );
        expect(
          read,
          contains(
            es ? '2 de 3 periodos hasta ahora.' : '2 of 3 periods so far.',
          ),
        );
        // No projected number for a habit without enough history.
        expect(read, isNot(contains(es ? 'unos ' : 'about ')));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a line for another range is not shown', (tester) async {
      await pumpFutureOutcomes(
        tester,
        habitsFor: (int days) => futureOutcomesHabitLines(30),
      );
      expect(
        find.descendant(
          of: habits,
          matching: find.text('Checking your habits…'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('habit-line-habit-walk')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a check-in updates the row and keeps the selected option', (
      tester,
    ) async {
      final lines =
          NotifierProvider<
            FutureOutcomesValue<TrajectoryHabitLines>,
            TrajectoryHabitLines
          >(() => FutureOutcomesValue(futureOutcomesHabitLines(7)));
      final ProviderContainer container = await pumpFutureOutcomes(
        tester,
        defaultHabits: false,
        extraOverrides: [
          trajectoryHabitLinesProvider.overrideWith(
            (Ref ref) => ref.watch(lines),
          ),
        ],
      );
      await tapFutureOutcomes(
        tester,
        find.byKey(const ValueKey<String>('option-remove-task-d')),
      );
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      final TrajectoryHabitLines before = container.read(lines);
      final TrajectoryHabitNode walk = before.nodes.first;
      container
          .read(lines.notifier)
          .set(
            TrajectoryHabitLines(
              status: TrajectoryHabitLinesStatus.ready,
              horizonDays: 7,
              nodes: <TrajectoryHabitNode>[
                TrajectoryHabitNode(
                  habitId: walk.habitId,
                  title: walk.title,
                  cadence: walk.cadence,
                  closedPeriodsJudged: walk.closedPeriodsJudged + 1,
                  completedPeriods: walk.completedPeriods + 1,
                  rate: walk.rate,
                  expectedPeriods: 7,
                  projectedCheckIns: const TrajectoryExpectedCompletions(
                    low: 5,
                    mid: 6,
                    high: 7,
                  ),
                  checkedInThisPeriod: true,
                  evidence: TrajectoryHabitEvidence.enough,
                ),
                before.nodes.last,
              ],
              revision: 'habits-after-check-in',
            ),
          );
      await settleFutureOutcomes(tester);
      expect(
        textsIn(
          tester,
          find.byKey(const ValueKey<String>('habit-line-habit-walk')),
        ),
        contains('about 6 of 7 check-ins'),
      );
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the selected option', () {
    testWidgets('survives a refresh that renames the option, by its kind', (
      tester,
    ) async {
      final reduceId = NotifierProvider<FutureOutcomesValue<String>, String>(
        () => FutureOutcomesValue('remove-task-d'),
      );
      final ProviderContainer container = await pumpFutureOutcomes(
        tester,
        defaultModel: false,
        extraOverrides: [
          trajectoryEngineModelProvider.overrideWith(
            (Ref ref) => futureOutcomesModel(
              comparison: futureOutcomesComparison(
                baseline: futureOutcomesBaseline(
                  revision: 'rev-${ref.watch(reduceId)}',
                ),
                reduceId: ref.watch(reduceId),
              ),
            ),
          ),
        ],
      );
      expect(
        textsIn(tester, selectedCard),
        isNot(contains('Reduce lower-priority scope')),
      );
      await tapFutureOutcomes(
        tester,
        find.byKey(const ValueKey<String>('option-remove-task-d')),
      );
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      container.read(reduceId.notifier).set('remove-task-d-after-refresh');
      await settleFutureOutcomes(tester);
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a range change when the same kind exists', (
      tester,
    ) async {
      await pumpFutureOutcomes(tester);
      await tapFutureOutcomes(
        tester,
        find.byKey(const ValueKey<String>('option-remove-task-d')),
      );
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      await tapFutureOutcomes(tester, find.text('30 days'));
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      expect(textsIn(tester, selectedCard), contains('over the next 30 days'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to the recommended option only when the kind is '
        'gone', (tester) async {
      await pumpFutureOutcomes(
        tester,
        modelFor: (int days) => futureOutcomesModel(
          comparison: futureOutcomesComparison(
            days: days,
            withReduce: days == 7,
          ),
        ),
      );
      await tapFutureOutcomes(
        tester,
        find.byKey(const ValueKey<String>('option-remove-task-d')),
      );
      expect(
        textsIn(tester, selectedCard),
        contains('Reduce lower-priority scope'),
      );
      await tapFutureOutcomes(tester, find.text('30 days'));
      final TrajectoryComparison thirty = futureOutcomesComparison(
        days: 30,
        withReduce: false,
      );
      expect(
        textsIn(tester, selectedCard),
        contains(thirty.recommended!.intervention.title),
      );
      expect(
        textsIn(tester, selectedCard),
        isNot(contains('Reduce lower-priority scope')),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('equal shown workload', () {
    testWidgets('ranked options with the same whole percent give the reason', (
      tester,
    ) async {
      final ProviderContainer container = await pumpFutureOutcomes(tester);
      // At 7 days the visible options all show different percents.
      expect(
        find.textContaining('Same shown workload as another option'),
        findsNothing,
      );
      await tapFutureOutcomes(tester, find.text('90 days'));
      final TrajectoryComparison ninety = container
          .read(trajectoryEngineModelProvider)
          .comparison!;
      int shown(String id) => ninety.outcomes
          .firstWhere((o) => o.intervention.id == id)
          .projectedPressure;
      // The fixture: finishing the proposal and removing the inbox task both
      // round to the same whole percent, but rank differently.
      expect(shown('complete-task-a'), shown('remove-task-d'));
      final String complete = textsIn(
        tester,
        find.byKey(const ValueKey<String>('option-complete-task-a')),
      );
      final String remove = textsIn(
        tester,
        find.byKey(const ValueKey<String>('option-remove-task-d')),
      );
      expect(complete, contains('Same shown workload as another option'));
      expect(complete, contains('frees about 60 minutes in this range'));
      // One of the reasons, not the whole cause.
      expect(
        complete,
        contains('the order also weighs pace, risk and goal dates'),
      );
      expect(remove, contains('Same shown workload as another option'));
      expect(remove, contains('frees about 30 minutes in this range'));
      expect(
        textsIn(tester, find.byKey(const ValueKey<String>('option-planner'))),
        isNot(contains('Same shown workload')),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a task outside the range frees no time', (tester) async {
      // Finishing the review (due in 20 days) frees nothing over 7 days, so
      // it shows the same workload as keeping going.
      final TrajectoryBaseline baseline = futureOutcomesBaseline();
      final TrajectoryComparison comparison = const FutureConsequenceEngine()
          .compare(
            baseline: baseline,
            generatedAt: trajectoryFixtureNow,
            interventions: <TrajectoryIntervention>[
              TrajectoryIntervention(
                id: 'maintain',
                type: TrajectoryInterventionType.maintainCourse,
                title: 'Maintain current course',
                horizon: const Duration(days: 7),
                description: 'Keep the present plan unchanged.',
              ),
              TrajectoryIntervention(
                id: 'complete-task-b',
                type: TrajectoryInterventionType.completeTask,
                title: 'Complete Prepare the review',
                horizon: const Duration(days: 7),
                description: 'Finish the review early.',
                subjectId: 'task-b',
              ),
            ],
          );
      await pumpFutureOutcomes(
        tester,
        modelFor: (_) => futureOutcomesModel(comparison: comparison),
      );
      expect(
        comparison.outcomes[0].projectedPressure,
        comparison.outcomes[1].projectedPressure,
      );
      expect(
        textsIn(
          tester,
          find.byKey(const ValueKey<String>('option-complete-task-b')),
        ),
        contains('frees no time in this range'),
      );
      expect(
        textsIn(tester, find.byKey(const ValueKey<String>('option-maintain'))),
        contains('This one frees no time in this range; pace unchanged.'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
