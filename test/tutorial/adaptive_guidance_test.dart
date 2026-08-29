import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
              now: observedAt.add(const Duration(days: 2)),
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
              now: observedAt.add(const Duration(days: 2)),
            )
            ?.id,
        GuidanceLessonId.nexus,
      );
    },
  );

  test(
    'finishing core setup returns control to Nexus before advanced help',
    () {
      final DateTime observedAt = DateTime.utc(2026, 8, 20, 17);
      final AdaptiveGuidanceState state = AdaptiveGuidanceState(
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

      expect(
        state.nextIntervention(
          currentRoute: RoutePaths.nexus,
          decision: _decision,
          now: observedAt.add(const Duration(minutes: 1)),
        ),
        isNull,
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

  test('existing tasks repair missing first-run milestones durably', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _GuidanceTaskRepository repository =
        _GuidanceTaskRepository(<TaskEntity>[
          TaskEntity(
            id: 'existing-scheduled-task',
            title: 'Already on Timeline',
            createdAt: DateTime.utc(2026, 8, 20, 9),
            scheduledFor: DateTime.utc(2026, 8, 20, 10),
          ),
        ]);
    final ProviderContainer first = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('guidance-repair-user'),
        ),
        domainTaskRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final AdaptiveGuidanceState repaired = await first.read(
      adaptiveGuidanceProvider.future,
    );
    expect(repaired.has(GuidanceMilestone.firstItem), isTrue);
    expect(repaired.has(GuidanceMilestone.firstSchedule), isTrue);
    first.dispose();

    final ProviderContainer restarted = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('guidance-repair-user'),
        ),
        domainTaskRepositoryProvider.overrideWithValue(
          _GuidanceTaskRepository(const <TaskEntity>[]),
        ),
      ],
    );
    addTearDown(restarted.dispose);
    final AdaptiveGuidanceState persisted = await restarted.read(
      adaptiveGuidanceProvider.future,
    );

    expect(persisted.has(GuidanceMilestone.firstItem), isTrue);
    expect(persisted.has(GuidanceMilestone.firstSchedule), isTrue);
  });
}

class _GuidanceTaskRepository implements ITaskRepository {
  _GuidanceTaskRepository(this.tasks);

  final List<TaskEntity> tasks;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks;

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      tasks.where((TaskEntity task) => task.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {}
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
