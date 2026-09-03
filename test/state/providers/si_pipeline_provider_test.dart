import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/entities/log_entry_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';
import 'package:fantastic_guacamole/domain/planning/adaptive_plan_policy.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_decision_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/state/logs_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_task_repository.dart';

void main() {
  test('SI aggregation composes the three read-only screen models', () async {
    final DateTime now = DateTime.now();
    final Task task = Task(
      id: 'task-1',
      title: 'Repair the coverage gate',
      priority: 5,
      difficulty: 3,
      energyRequired: 3,
    );
    final TimelineEventEntity overdue = TimelineEventEntity(
      id: 'overdue-1',
      type: TimelineEventType.deadline,
      title: 'Priority 7 deadline',
      detail: 'Coverage remains below target',
      timestamp: now.subtract(const Duration(days: 2)),
      status: TimelineEventStatus.overdue,
    );
    final SIStateAggregation aggregation = SIStateAggregation(
      tasks: <Task>[task],
      goals: <GoalEntity>[
        GoalEntity(id: 'goal-1', title: 'Closed test', createdAt: now),
      ],
      habits: <HabitEntity>[
        HabitEntity(id: 'habit-1', title: 'Daily review', createdAt: now),
      ],
      planningEvidence: const SIPlanningEvidence(
        friction: true,
        overwhelm: false,
        streakHealth: 'stable',
        goalDrift: false,
        taskAvoidance: true,
        emotion: 'neutral',
        emotionalStrain: false,
        emotionalStability: true,
        emotionalPatterns: <String>['stable'],
        executionCompletedToday: 1,
        executionSkippedToday: 1,
        executionDelayedToday: 1,
      ),
      logs: const [],
      timeline: <TimelineEventEntity>[overdue],
      memories: const [],
      notifications: const [],
      planPreview: const <String>['Repair the coverage gate'],
      profile: ProfileState(streak: 4),
      siState: const SIState(energy: .7, fatigue: .3),
      trajectory: const TrajectorySummaryView(
        pendingTasks: 1,
        completedTasks: 2,
        completedToday: 1,
        level: 2,
        streak: 4,
        energy: .7,
        momentum: .6,
        adaptability: .7,
        lastCompletionXp: 20,
        lastCompletionQuality: .8,
        pressureIndex: 65,
        behaviorDivergence: 20,
        alert: 'Coverage needs attention',
        predictionTitle: null,
        predictionOutcome: null,
        predictionProbability: null,
        predictionExplanation: null,
      ),
      signals: const SignalsBundle(
        items: [],
        summary: 'Current evidence',
        healthScore: .7,
      ),
      sourceHealth: SISourceHealth(
        tasks: SISourceStatus.ready,
        goals: SISourceStatus.ready,
        memories: SISourceStatus.empty,
        habits: SISourceStatus.ready,
        logs: SISourceStatus.empty,
        timeline: SISourceStatus.ready,
        learning: SISourceStatus.ready,
        availability: SISourceStatus.unavailable,
        observedAt: now,
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        siStateAggregationProvider.overrideWith((Ref ref) async => aggregation),
        timelineProvider.overrideWith(
          () => _StaticTimeline(<TimelineEventEntity>[overdue]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final SIDecisionOutput decision = await container.read(
      siDecisionOutputProvider.future,
    );
    expect(decision.nextAction, contains('Repair the coverage gate'));
    expect(decision.warnings, isNotEmpty);

    final SmartPlannerScreenModel planner = await container.read(
      smartPlannerScreenModelProvider.future,
    );
    final NexusScreenModel nexus = await container.read(
      nexusScreenModelProvider.future,
    );
    final SIConsoleScreenModel console = await container.read(
      siConsoleScreenModelProvider.future,
    );
    expect(planner.aggregation, same(aggregation));
    expect(planner.decision.nextAction, decision.nextAction);
    expect(nexus.aggregation, same(aggregation));
    expect(console.aggregation, same(aggregation));
    expect(console.engineSnapshot, contains('tasks 1'));
    expect(console.engineSnapshot, contains('Timeline 1'));
    expect(console.engineSnapshot, contains('memories 0'));
    expect(aggregation.activeHabitCount, 1);
    expect(aggregation.sourceHealth.availableFraction, .875);
  });

  test('SI decision remains explicit when every source is empty', () async {
    final SIStateAggregation aggregation = SIStateAggregation(
      tasks: const <Task>[],
      goals: const <GoalEntity>[],
      planningEvidence: const SIPlanningEvidence(
        friction: false,
        overwhelm: false,
        streakHealth: 'unknown',
        goalDrift: false,
        taskAvoidance: false,
        emotion: 'unknown',
        emotionalStrain: false,
        emotionalStability: false,
        emotionalPatterns: <String>[],
      ),
      logs: const [],
      timeline: const [],
      memories: const [],
      notifications: const [],
      planPreview: const [],
      profile: ProfileState(),
      siState: const SIState(),
      trajectory: const TrajectorySummaryView(
        pendingTasks: 0,
        completedTasks: 0,
        completedToday: 0,
        level: 1,
        streak: 0,
        energy: .5,
        momentum: 0,
        adaptability: .5,
        lastCompletionXp: 0,
        lastCompletionQuality: 0,
        pressureIndex: 0,
        behaviorDivergence: 0,
        alert: '',
        predictionTitle: null,
        predictionOutcome: null,
        predictionProbability: null,
        predictionExplanation: null,
      ),
      signals: const SignalsBundle(items: [], summary: '', healthScore: 0),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        siStateAggregationProvider.overrideWith((Ref ref) async => aggregation),
        timelineProvider.overrideWith(
          () => _StaticTimeline(const <TimelineEventEntity>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final SIDecisionOutput decision = await container.read(
      siDecisionOutputProvider.future,
    );
    expect(decision.nextAction, isNotEmpty);
    expect(aggregation.activeHabitCount, 0);
    expect(aggregation.sourceHealth.availableFraction, .875);
  });

  test(
    'SI aggregation filters tasks and reports source health honestly',
    () async {
      final DateTime now = DateTime.now();
      final TaskEntity actionable = TaskEntity(
        id: 'active',
        title: 'Active task',
        createdAt: now,
        priority: 5,
        difficulty: 3,
        energyRequired: 3,
      );
      final TaskEntity completed = actionable.copyWith(
        id: 'completed',
        title: 'Completed task',
        isCompleted: true,
        completedAt: now,
      );
      final GoalEntity goal = GoalEntity(
        id: 'goal-1',
        title: 'Release goal',
        createdAt: now,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            AccountStorageScope.authenticated('si-pipeline-test'),
          ),
          domainTaskRepositoryProvider.overrideWithValue(
            FakeTaskRepository(<TaskEntity>[actionable, completed]),
          ),
          domainLearningRepositoryProvider.overrideWithValue(
            _StaticLearningRepository(LearningEntity()),
          ),
          learningPausedProvider.overrideWith((Ref ref) async => false),
          personContextForSurfaceProvider(
            sharedDecisionPersonContextRequest,
          ).overrideWithValue(null),
          adaptivePlanPolicyProvider.overrideWithValue(
            const AdaptivePlanPolicy(),
          ),
          goalsProvider.overrideWith(() => _StaticGoals(<GoalEntity>[goal])),
          habitsProvider.overrideWith(
            () => _StaticHabits(<HabitEntity>[
              HabitEntity(id: 'habit-1', title: 'Review', createdAt: now),
            ]),
          ),
          signalsBundleProvider.overrideWithValue(
            const SignalsBundle(
              items: <Signal>[
                Signal(title: 'Pressure', description: 'Moderate'),
              ],
              summary: 'Pressure is moderate',
              healthScore: .7,
            ),
          ),
          logsProvider.overrideWith(
            () => _StaticLogs(
              LogsState(
                entries: <LogEntryEntity>[
                  LogEntryEntity(
                    id: 'completed-log',
                    message: 'Completed',
                    source: 'task_completed',
                    timestamp: now,
                  ),
                  LogEntryEntity(
                    id: 'skipped-log',
                    message: 'Skipped',
                    source: 'task_skipped',
                    timestamp: now,
                  ),
                  LogEntryEntity(
                    id: 'delayed-log',
                    message: 'Delayed',
                    source: 'task_delayed',
                    timestamp: now,
                  ),
                ],
                isLoading: false,
              ),
            ),
          ),
          timelineProvider.overrideWith(
            () => _StaticTimeline(const <TimelineEventEntity>[]),
          ),
          notificationProvider.overrideWith(
            () => _StaticNotifications(const <NotificationEntity>[]),
          ),
          profileProvider.overrideWith(
            () => _StaticProfile(ProfileState(streak: 4)),
          ),
          consentedHumanContextProvider.overrideWithValue(
            const ConsentedHumanContext(
              emotionAllowed: false,
              memoryAllowed: false,
              emotion: null,
              siState: SIState(energy: .7, fatigue: .2),
            ),
          ),
          trajectorySummaryProvider.overrideWithValue(
            const TrajectorySummaryView(
              pendingTasks: 1,
              completedTasks: 1,
              completedToday: 1,
              level: 2,
              streak: 4,
              energy: .7,
              momentum: .6,
              adaptability: .7,
              lastCompletionXp: 20,
              lastCompletionQuality: .8,
              pressureIndex: 55,
              behaviorDivergence: 15,
              alert: 'Stable',
              predictionTitle: null,
              predictionOutcome: null,
              predictionProbability: null,
              predictionExplanation: null,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<SIStateAggregation>> subscription =
          container.listen<AsyncValue<SIStateAggregation>>(
            siStateAggregationProvider,
            (_, _) {},
          );
      addTearDown(subscription.close);

      final SIStateAggregation result = await container.read(
        siStateAggregationProvider.future,
      );
      expect(result.tasks.map((Task task) => task.id), <String>['active']);
      expect(result.goals.single.id, 'goal-1');
      expect(result.habits.single.id, 'habit-1');
      expect(result.memories, isEmpty);
      expect(result.sourceHealth.tasks, SISourceStatus.ready);
      expect(result.sourceHealth.goals, SISourceStatus.ready);
      expect(result.sourceHealth.memories, SISourceStatus.empty);
      expect(result.sourceHealth.habits, SISourceStatus.ready);
      expect(result.sourceHealth.logs, SISourceStatus.ready);
      expect(result.sourceHealth.timeline, SISourceStatus.empty);
      expect(result.sourceHealth.learning, SISourceStatus.ready);
      expect(result.sourceHealth.availability, SISourceStatus.unavailable);
      expect(result.planningEvidence.executionCompletedToday, 1);
      expect(result.planningEvidence.executionSkippedToday, 1);
      expect(result.planningEvidence.executionDelayedToday, 1);
      expect(result.planPreview, isNotEmpty);
    },
  );
}

final class _StaticTimeline extends TimelineNotifier {
  _StaticTimeline(this._value);

  final List<TimelineEventEntity> _value;

  @override
  List<TimelineEventEntity> build() => _value;
}

final class _StaticGoals extends GoalsNotifier {
  _StaticGoals(this._value);

  final List<GoalEntity> _value;

  @override
  List<GoalEntity> build() => _value;
}

final class _StaticHabits extends HabitsNotifier {
  _StaticHabits(this._value);

  final List<HabitEntity> _value;

  @override
  Future<List<HabitEntity>> build() async => _value;
}

final class _StaticLogs extends LogsController {
  _StaticLogs(this._value);

  final LogsState _value;

  @override
  LogsState build() => _value;
}

final class _StaticNotifications extends NotificationNotifier {
  _StaticNotifications(this._value);

  final List<NotificationEntity> _value;

  @override
  List<NotificationEntity> build() => _value;
}

final class _StaticProfile extends ProfileController {
  _StaticProfile(this._value);

  final ProfileState _value;

  @override
  ProfileState build() => _value;
}

final class _StaticLearningRepository implements ILearningRepository {
  _StaticLearningRepository(this._value);

  LearningEntity? _value;

  @override
  Future<LearningEntity?> getState() async => _value;

  @override
  Future<void> saveState(LearningEntity state) async {
    _value = state;
  }
}
