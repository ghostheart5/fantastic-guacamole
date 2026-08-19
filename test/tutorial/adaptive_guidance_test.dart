import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'core lessons unlock advanced guidance only after observed milestones',
    () {
      final DateTime observedAt = DateTime.utc(2026, 8, 18);
      final AdaptiveGuidanceState incomplete = AdaptiveGuidanceState(
        milestones: <GuidanceMilestone, DateTime>{
          GuidanceMilestone.firstItem: observedAt,
        },
        counts: const <GuidanceMilestone, int>{},
        skippedLessons: const <GuidanceLessonId>{},
        completedLessons: const <GuidanceLessonId>{
          GuidanceLessonId.createFirstItem,
        },
      );

      expect(incomplete.coreComplete, isFalse);
      expect(
        incomplete
            .nextIntervention(
              currentRoute: RoutePaths.nexus,
              decision: _decision,
            )
            ?.id,
        GuidanceLessonId.scheduleFirstItem,
      );

      final AdaptiveGuidanceState complete = AdaptiveGuidanceState(
        milestones: <GuidanceMilestone, DateTime>{
          GuidanceMilestone.firstItem: observedAt,
          GuidanceMilestone.firstSchedule: observedAt,
          GuidanceMilestone.firstTimelineReview: observedAt,
        },
        counts: const <GuidanceMilestone, int>{},
        skippedLessons: const <GuidanceLessonId>{},
        completedLessons: const <GuidanceLessonId>{
          GuidanceLessonId.createFirstItem,
          GuidanceLessonId.scheduleFirstItem,
          GuidanceLessonId.reviewTimeline,
        },
      );

      expect(complete.coreComplete, isTrue);
      expect(
        complete
            .nextIntervention(
              currentRoute: RoutePaths.nexus,
              decision: _decision,
            )
            ?.id,
        GuidanceLessonId.nexus,
      );
    },
  );

  test('completed and skipped lessons are suppressed', () {
    final DateTime observedAt = DateTime.utc(2026, 8, 18);
    final AdaptiveGuidanceState state = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: observedAt,
        GuidanceMilestone.firstSchedule: observedAt,
        GuidanceMilestone.firstTimelineReview: observedAt,
      },
      counts: const <GuidanceMilestone, int>{},
      skippedLessons: const <GuidanceLessonId>{GuidanceLessonId.nexus},
      completedLessons: const <GuidanceLessonId>{
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
        GuidanceLessonId.smartPlanner,
      },
    );

    expect(
      state
          .nextIntervention(
            currentRoute: RoutePaths.timeline,
            decision: _decision,
          )
          ?.id,
      GuidanceLessonId.timelineExecution,
    );
  });

  test('repeated deferral selects a correction intervention', () {
    final DateTime observedAt = DateTime.utc(2026, 8, 18);
    final AdaptiveGuidanceState state = AdaptiveGuidanceState(
      milestones: <GuidanceMilestone, DateTime>{
        GuidanceMilestone.firstItem: observedAt,
        GuidanceMilestone.firstSchedule: observedAt,
        GuidanceMilestone.firstTimelineReview: observedAt,
      },
      counts: const <GuidanceMilestone, int>{
        GuidanceMilestone.firstTaskDeferral: 2,
      },
      skippedLessons: const <GuidanceLessonId>{},
      completedLessons: const <GuidanceLessonId>{
        GuidanceLessonId.createFirstItem,
        GuidanceLessonId.scheduleFirstItem,
        GuidanceLessonId.reviewTimeline,
      },
    );

    expect(
      state
          .nextIntervention(currentRoute: RoutePaths.nexus, decision: _decision)
          ?.id,
      GuidanceLessonId.timelineExecution,
    );
  });
}

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
