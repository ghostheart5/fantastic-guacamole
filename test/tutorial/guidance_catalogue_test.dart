import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
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

    test('Spanish hint text comes from the catalogue', () {
      const ChronoSparkLocalizations spanish = ChronoSparkLocalizations(
        Locale('es'),
      );
      for (final GuidanceHint hint in GuidanceCatalogue.hints) {
        final String id = hint.id.name;
        expect(spanish.guideTitle(id, 'x'), hint.title.es, reason: id);
        expect(spanish.guideBody(id, 'x'), hint.body.es, reason: id);
        if (hint.action case final GuidanceAction action) {
          expect(spanish.guideAction(id, 'x'), action.label.es, reason: id);
        }
      }
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
      GuidancePlaces.none,
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
