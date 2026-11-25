import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_replanning_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every contextual hint lives in one catalogue; the four hints for habits,
/// goals, reminders and notification settings appear once, on their own
/// screen only.
void main() {
  final DateTime coreDoneAt = DateTime.utc(2026, 8, 18);
  final DateTime later = coreDoneAt.add(const Duration(days: 3));

  group('the catalogue', () {
    test('every hint has both languages, a route and a completing '
        'interaction', () {
      expect(GuidanceCatalogue.all, isNotEmpty);
      for (final GuidanceHint hint in GuidanceCatalogue.all) {
        final String name = hint.id.name;
        for (final GuidanceText text in <GuidanceText>[
          hint.title,
          hint.body,
          ?hint.action?.label,
        ]) {
          expect(text.en.trim(), isNotEmpty, reason: name);
          expect(text.es.trim(), isNotEmpty, reason: name);
          expect(text.es, isNot(text.en), reason: '$name needs Spanish');
        }
        expect(hint.route.trim(), isNotEmpty, reason: name);
        final GuidanceCompletion done = hint.completedBy;
        expect(
          done.milestones.isNotEmpty ||
              (done.byHintAction &&
                  hint.action?.kind == GuidanceActionKind.turnOnNotifications),
          isTrue,
          reason: '$name must say which real interaction finishes it',
        );
      }
    });

    test('lists each contextual lesson once and no first-run guide step', () {
      final List<GuidanceLessonId> listed = GuidanceCatalogue.hints
          .map((GuidanceHint hint) => hint.id)
          .toList();
      expect(listed.toSet(), hasLength(listed.length));
      for (final GuidanceLessonId id in GuidanceLessonId.values) {
        final bool core = AdaptiveGuidanceState.coreStepNumber(id) != null;
        expect(listed.contains(id), !core, reason: id.name);
      }
      // A place key is never a router path, so no location can match it.
      for (final GuidanceHint hint in GuidanceCatalogue.all) {
        if (!hint.route.startsWith('/')) {
          expect(hint.route, startsWith('place:'), reason: hint.id.name);
        }
      }
    });

    group('hint text is built from typed values, the same in both '
        'languages, never from engine sentences', () {
      final AdaptiveGuidanceState state = _coreDone(DateTime.utc(2026, 8, 18));
      final DateTime later = DateTime.utc(2026, 8, 21);
      GuidanceText? at(String route, DailyDecisionIntelligence decision) {
        final GuidanceLesson? lesson = state.nextIntervention(
          currentRoute: route,
          decision: decision,
          now: later,
        );
        final GuidanceText? text = lesson?.hintBody;
        // The English body the lesson reports is the same text.
        expect(lesson?.body, text?.en);
        return text;
      }

      test('Choose a step', () {
        final GuidanceText? plain = at(RoutePaths.smartPlanner, _decision);
        expect(
          plain?.en,
          'Ask one clear question about the suggested task, what is holding '
          'it back, or what could move. Type a question to get a suggestion.',
        );
        expect(
          plain?.es,
          'Haz una pregunta clara sobre la tarea sugerida, lo que la frena o '
          'lo que podría moverse. Escribe una pregunta para recibir una '
          'sugerencia.',
        );
        // The kind of today's replanning suggestion says what it is about,
        // in both languages; the engine's English sentence is never copied.
        final Map<AdaptiveReplanningType, (String, String)> byType =
            <AdaptiveReplanningType, (String, String)>{
              AdaptiveReplanningType.missedCommitment: (
                'You moved or skipped a task today. Try asking how to turn it '
                    'into one small step you can finish.',
                'Hoy moviste u omitiste una tarea. Prueba a preguntar cómo '
                    'convertirla en un paso pequeño que puedas terminar.',
              ),
              AdaptiveReplanningType.overloadedDay: (
                'Today looks too full. Try asking which task you could move '
                    'to make room.',
                'Hoy parece demasiado lleno. Prueba a preguntar qué tarea '
                    'podrías mover para hacer espacio.',
              ),
              AdaptiveReplanningType.lowEnergy: (
                'Your energy is low today. Try asking for the smallest useful '
                    'step.',
                'Hoy tienes poca energía. Prueba a pedir el paso útil más '
                    'pequeño.',
              ),
              AdaptiveReplanningType.momentumRecovery: (
                'Your recent progress is slow. Try asking which open task to '
                    'finish first.',
                'Tu avance reciente es lento. Prueba a preguntar qué tarea '
                    'abierta terminar primero.',
              ),
            };
        for (final AdaptiveReplanningType type
            in AdaptiveReplanningType.values) {
          final GuidanceText? change = at(
            RoutePaths.smartPlanner,
            _decisionWith(
              replanType: type,
              replanAction: 'Move Task A to 3 pm.',
            ),
          );
          final (String, String)? expected = byType[type];
          // "Keep going" suggests no change, so the plain text stays.
          expect(change?.en, expected?.$1 ?? plain?.en, reason: type.name);
          expect(change?.es, expected?.$2 ?? plain?.es, reason: type.name);
          expect(change?.en, isNot(contains('Task A')));
        }
      });

      test('Today', () {
        final GuidanceText? text = at(RoutePaths.nexus, _decision);
        expect(
          text?.en,
          'Read why it was suggested and what is uncertain before deciding.',
        );
        expect(
          text?.es,
          'Lee por qué se sugirió y qué es incierto antes de decidir.',
        );
        expect(text?.en, isNot(contains(_decision.rationale)));
      });

      test('Chat: the typed plan warning replaces the check on an English '
          'sentence prefix', () {
        // No plan warning: the hint has no warning line, whatever the
        // engine's sentence says.
        for (final String warning in <String>[
          'No material constraint is supported by the current evidence.',
          'Decision evidence is still loading; constraints are not yet '
              'resolved.',
        ]) {
          final GuidanceText? calm = at(
            RoutePaths.siConsole,
            _decisionWith(warning: warning),
          );
          expect(calm?.en, GuidanceCatalogue.siConsole.body.en);
          expect(calm?.es, GuidanceCatalogue.siConsole.body.es);
        }
        // A plan warning adds one plain line in both languages that says
        // what it is about, and never the engine's own sentence.
        final Map<PlanWarningKind, (String, String)> leads =
            <PlanWarningKind, (String, String)>{
              PlanWarningKind.decision: (
                "Today's plan has a warning, and you can ask about it here.",
                'El plan de hoy tiene un aviso y puedes preguntar por él aquí.',
              ),
              PlanWarningKind.deferrals: (
                'You moved or skipped more than one task today.',
                'Hoy moviste u omitiste más de una tarea.',
              ),
              PlanWarningKind.overload: (
                'Today has more work than time.',
                'Hoy tienes más trabajo que tiempo.',
              ),
            };
        for (final PlanWarningKind kind in PlanWarningKind.values) {
          final GuidanceText? warned = at(
            RoutePaths.siConsole,
            _decisionWith(
              warning: 'No material constraint, but recent deferrals pile up.',
              planWarning: kind,
            ),
          );
          expect(
            warned?.en,
            '${leads[kind]!.$1} ${GuidanceCatalogue.siConsole.body.en}',
            reason: kind.name,
          );
          expect(
            warned?.es,
            '${leads[kind]!.$2} ${GuidanceCatalogue.siConsole.body.es}',
            reason: kind.name,
          );
          expect(warned?.en, isNot(contains('pile up')));
        }
        expect(
          GuidanceCatalogue.siConsole.body.en,
          startsWith(
            'Ask what is missing from your plan, or what would change the '
            'suggestion. ',
          ),
        );
        expect(
          GuidanceCatalogue.siConsole.body.es,
          startsWith(
            'Pregunta qué falta en tu plan o qué cambiaría la sugerencia. ',
          ),
        );
      });

      test('every other hint shows its catalogue text', () {
        for (final GuidanceHint hint in <GuidanceHint>[
          GuidanceCatalogue.timelineExecution,
          GuidanceCatalogue.trajectoryEngine,
          GuidanceCatalogue.progression,
        ]) {
          final GuidanceText? text = at(hint.route, _decision);
          expect(text?.en, hint.body.en, reason: hint.id.name);
          expect(text?.es, hint.body.es, reason: hint.id.name);
        }
      });
    });

    test('guidance sending someone to a screen names it as the control they '
        'tap does (the navigation label)', () {
      const ChronoSparkLocalizations en = ChronoSparkLocalizations(
        Locale('en'),
      );
      const ChronoSparkLocalizations es = ChronoSparkLocalizations(
        Locale('es'),
      );
      // Step 2 of the first-run guide sends the person to /timeline, whose
      // navigation label is My plan.
      final GuidanceLesson? step2 =
          AdaptiveGuidanceState(
            milestones: <GuidanceMilestone, DateTime>{
              GuidanceMilestone.firstItem: coreDoneAt,
              GuidanceMilestone.firstSchedule: coreDoneAt,
            },
            counts: const <GuidanceMilestone, int>{},
            skippedLessons: const <GuidanceLessonId>{},
            completedLessons: const <GuidanceLessonId>{},
            expectedFirstRunCreatorTaskIds: const <String>{'task'},
          ).nextIntervention(
            currentRoute: RoutePaths.nexus,
            decision: _decision,
            now: later,
          );
      expect(step2?.id, GuidanceLessonId.reviewTimeline);
      expect(step2?.route, RoutePaths.timeline);
      final String label = step2!.actionLabel;
      expect(en.guideAction(step2.id.name, label), 'Open My plan');
      expect(es.guideAction(step2.id.name, label), 'Abrir Mi plan');
      expect(en.text(ChronoSparkString.timeline), 'My plan');
      expect(es.text(ChronoSparkString.timeline), 'Mi plan');
    });

    test('hint wording names each screen as its navigation label does', () {
      expect(GuidanceCatalogue.siConsole.action?.label.en, 'Ask in Chat');
      expect(GuidanceCatalogue.siConsole.action?.label.es, 'Preguntar en Chat');
      expect(
        GuidanceCatalogue.timelineExecution.action?.label.en,
        'Open My plan',
      );
      expect(
        GuidanceCatalogue.timelineExecution.action?.label.es,
        'Abrir Mi plan',
      );
      expect(
        GuidanceCatalogue.timelineRecovery.action?.label.en,
        'Review in My plan',
      );
      expect(GuidanceCatalogue.progression.action?.label.en, 'Review activity');
      expect(
        GuidanceCatalogue.progression.action?.label.es,
        'Revisar actividad',
      );
      expect(
        GuidanceCatalogue.trajectoryEngine.body.es,
        'Prueba otra hora, otra cantidad de trabajo u otra prioridad. '
        'Compara la estimación antes de cambiar tu plan.',
      );
      expect(
        GuidanceCatalogue.progression.body.es,
        'Ve las tareas y los hitos que registraste. Abre los detalles para '
        'revisarlos.',
      );
      expect(
        GuidanceCatalogue.timelineExecution.body.es,
        'Abre una tarea con fecha. Márcala como hecha, muévela o corrige sus '
        'detalles y guarda el cambio.',
      );
    });

    test('the "Continue here" string the hint card replaced is gone', () {
      expect(
        ChronoSparkString.values.map((ChronoSparkString key) => key.name),
        isNot(contains('useThisScreen')),
      );
    });

    test('the personalization strings of the removed setup step are gone', () {
      final Set<String> names = ChronoSparkString.values
          .map((ChronoSparkString key) => key.name)
          .toSet();
      for (final String removed in <String>[
        'nameQuestion',
        'name',
        'nameHint',
        'primaryGoal',
        'goalExecution',
        'goalGrowth',
        'goalWellness',
        'goalExplore',
        'personalize',
        'lifeDirection',
        'calibrateExperience',
        'onboardingPrivacy',
        'onboardingWideBody',
        'onboardingCompactBody',
      ]) {
        expect(names, isNot(contains(removed)));
      }
    });
  });

  group('the new hints', () {
    final AdaptiveGuidanceState state = _coreDone(coreDoneAt);
    final List<String> everyPlace = <String>{
      for (final GuidanceHint hint in GuidanceCatalogue.all) hint.route,
      RoutePaths.settings,
      RoutePaths.creator,
      RoutePaths.notifications,
      RoutePaths.home,
      RoutePaths.shell,
      GuidancePlaces.undeclaredScreen(Object()),
      '/habits',
    }.toList();

    for (final GuidanceHint hint in <GuidanceHint>[
      GuidanceCatalogue.habits,
      GuidanceCatalogue.goals,
      GuidanceCatalogue.notificationSettings,
    ]) {
      test('${hint.id.name} appears on its own screen and nowhere else', () {
        final GuidanceLesson? own = state.nextIntervention(
          currentRoute: hint.route,
          decision: _decision,
          now: later,
        );
        expect(own?.id, hint.id);
        expect(own?.route, hint.route);
        expect(own?.title, hint.title.en);
        expect(own?.body, hint.body.en);
        for (final String place in everyPlace) {
          if (place == hint.route) continue;
          expect(
            state
                .nextIntervention(
                  currentRoute: place,
                  decision: _decision,
                  now: later,
                )
                ?.id,
            isNot(hint.id),
            reason: '${hint.id.name} must not appear on $place',
          );
        }
        // Once seen or finished by its real action it does not return.
        expect(
          _with(state, completed: hint.id).nextIntervention(
            currentRoute: hint.route,
            decision: _decision,
            now: later,
          ),
          isNull,
        );
        // Its real action finishes it (the overlay then closes the card;
        // stored state also lists it as completed).
        final GuidanceMilestone milestone = hint.completedBy.milestones.single;
        expect(
          _with(state, milestone: milestone).lessonFinishedByAction(hint.id),
          isTrue,
        );
      });
    }

    test('the reminders hint appears only right after a reminder was saved '
        'while notifications are off, on that screen', () {
      for (final String place in everyPlace) {
        expect(
          state
              .nextIntervention(
                currentRoute: place,
                decision: _decision,
                now: later,
              )
              ?.id,
          isNot(GuidanceLessonId.remindersOff),
          reason: place,
        );
      }
      final GuidanceLesson? afterSave = state.nextIntervention(
        currentRoute: RoutePaths.creator,
        decision: _decision,
        now: later,
        reminderSavedWhileNotificationsOff: true,
      );
      expect(afterSave?.id, GuidanceLessonId.remindersOff);
      expect(afterSave?.route, RoutePaths.creator);
      expect(afterSave?.hint, same(GuidanceCatalogue.remindersOff));
      // It wins over the screen's own hint, and also right after the
      // first-run guide, because it is about something just saved.
      final GuidanceLesson? onSchedule = _coreDone(coreDoneAt).nextIntervention(
        currentRoute: RoutePaths.timeline,
        decision: _decision,
        now: coreDoneAt.add(const Duration(minutes: 1)),
        reminderSavedWhileNotificationsOff: true,
      );
      expect(onSchedule?.id, GuidanceLessonId.remindersOff);
      for (final AdaptiveGuidanceState seen in <AdaptiveGuidanceState>[
        _with(state, completed: GuidanceLessonId.remindersOff),
        _with(state, skipped: GuidanceLessonId.remindersOff),
      ]) {
        expect(
          seen
              .nextIntervention(
                currentRoute: RoutePaths.creator,
                decision: _decision,
                now: later,
                reminderSavedWhileNotificationsOff: true,
              )
              ?.id,
          isNot(GuidanceLessonId.remindersOff),
        );
      }
    });

    test('an active first-run guide step still wins', () {
      const AdaptiveGuidanceState fresh = AdaptiveGuidanceState(
        milestones: <GuidanceMilestone, DateTime>{},
        counts: <GuidanceMilestone, int>{},
        skippedLessons: <GuidanceLessonId>{},
        completedLessons: <GuidanceLessonId>{},
      );
      for (final String place in <String>[
        GuidancePlaces.habits,
        RoutePaths.creatorGoals,
        GuidancePlaces.notificationSettings,
      ]) {
        expect(
          fresh
              .nextIntervention(
                currentRoute: place,
                decision: _decision,
                now: later,
                reminderSavedWhileNotificationsOff: true,
              )
              ?.id,
          GuidanceLessonId.createFirstItem,
        );
      }
    });
  });
}

AdaptiveGuidanceState _coreDone(DateTime at) => AdaptiveGuidanceState(
  milestones: <GuidanceMilestone, DateTime>{
    GuidanceMilestone.firstItem: at,
    GuidanceMilestone.firstSchedule: at,
    GuidanceMilestone.firstTimelineReview: at,
  },
  counts: const <GuidanceMilestone, int>{},
  skippedLessons: const <GuidanceLessonId>{},
  completedLessons: const <GuidanceLessonId>{
    GuidanceLessonId.createFirstItem,
    GuidanceLessonId.scheduleFirstItem,
    GuidanceLessonId.reviewTimeline,
  },
);

AdaptiveGuidanceState _with(
  AdaptiveGuidanceState state, {
  GuidanceLessonId? completed,
  GuidanceLessonId? skipped,
  GuidanceMilestone? milestone,
}) => AdaptiveGuidanceState(
  milestones: <GuidanceMilestone, DateTime>{
    ...state.milestones,
    ?milestone: DateTime.utc(2026, 8, 19),
  },
  counts: state.counts,
  skippedLessons: <GuidanceLessonId>{...state.skippedLessons, ?skipped},
  completedLessons: <GuidanceLessonId>{...state.completedLessons, ?completed},
);

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Work on Task A',
  momentum: '60% steady',
  trajectory: 'Stable',
  energy: '70% energy',
  warning: 'No material constraint is supported by the current evidence.',
  recovery: 'Protect a short recovery window.',
  recommendedAction: 'Work on Task A',
  rationale: 'Task A is the highest feasible item.',
  changeSummary: 'Task A moved up.',
  evidence: <String>['priority=5'],
  confidence: .7,
  observedOutcomes: 1,
);

DailyDecisionIntelligence _decisionWith({
  String? replanAction,
  String? warning,
  PlanWarningKind? planWarning,
  AdaptiveReplanningType? replanType,
}) => DailyDecisionIntelligence(
  primaryAction: _decision.primaryAction,
  momentum: _decision.momentum,
  trajectory: _decision.trajectory,
  energy: _decision.energy,
  warning: warning ?? _decision.warning,
  planWarning: planWarning,
  replanType: replanType,
  recovery: _decision.recovery,
  recommendedAction: _decision.recommendedAction,
  rationale: _decision.rationale,
  changeSummary: _decision.changeSummary,
  evidence: _decision.evidence,
  confidence: _decision.confidence,
  observedOutcomes: _decision.observedOutcomes,
  replanAction: replanAction,
);
