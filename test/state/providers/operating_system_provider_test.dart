import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/operating_system_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'task revision changes when priority changes without a count change',
    () {
      final SIStateAggregation before = _aggregation(<Task>[
        _task('task-a', priority: 2),
      ]);
      final SIStateAggregation after = _aggregation(<Task>[
        _task('task-a', priority: 5),
      ]);

      expect(before.tasks.length, after.tasks.length);
      expect(
        operatingSourceRevisions(before)['tasks'],
        isNot(operatingSourceRevisions(after)['tasks']),
      );
    },
  );

  test('task revision is stable when repository order changes', () {
    final SIStateAggregation first = _aggregation(<Task>[
      _task('task-a', priority: 2),
      _task('task-b', priority: 4),
    ]);
    final SIStateAggregation reordered = _aggregation(<Task>[
      _task('task-b', priority: 4),
      _task('task-a', priority: 2),
    ]);

    expect(
      operatingSourceRevisions(first)['tasks'],
      operatingSourceRevisions(reordered)['tasks'],
    );
  });

  test(
    'receipt action and subject come from the same canonical decision',
    () async {
      final SIStateAggregation aggregation = _aggregation(<Task>[
        _task('priority-task', priority: 5),
        _task('feasible-task', priority: 3),
      ]);
      final String selectedTitle =
          aggregation.planningDecision.selectedTask!.title;
      final String otherTitle = aggregation.tasks
          .firstWhere((Task task) => task.title != selectedTitle)
          .title;
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(
            const AccountStorageScope.signedOut(),
          ),
          siStateAggregationProvider.overrideWith(
            (Ref ref) async => aggregation,
          ),
          siDecisionOutputProvider.overrideWith(
            (Ref ref) async => SIDecisionOutput(
              nextAction: 'Work on: $otherTitle',
              plannerMessage: 'Intentionally mismatched supporting copy.',
              suggestedPlanAdjustments: const <String>[],
              signalPrompts: const <String>[],
              progressionFeedback: '',
              warnings: const <String>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final receipt = await container.read(
        operatingDecisionReceiptProvider.future,
      );

      expect(receipt.subjectId, aggregation.planningDecision.selectedTask!.id);
      expect(receipt.recommendedAction, contains(selectedTitle));
      expect(receipt.recommendedAction, isNot(contains(otherTitle)));
      expect(receipt.actionIntent.targetEntityId, receipt.subjectId);
    },
  );
}

Task _task(String id, {required int priority}) => Task(
  id: id,
  title: 'Task $id',
  priority: priority,
  difficulty: 3,
  energyRequired: 3,
  dueDate: DateTime.utc(2026, 8, 20),
  estimatedDuration: const Duration(minutes: 30),
);

SIStateAggregation _aggregation(List<Task> tasks) => SIStateAggregation(
  tasks: tasks,
  goals: const [],
  signals: const SignalsBundle(
    items: <Signal>[],
    summary: 'Stable',
    healthScore: .7,
  ),
  planningEvidence: const SIPlanningEvidence(
    friction: false,
    overwhelm: false,
    streakHealth: 'steady',
    goalDrift: false,
    taskAvoidance: false,
    emotion: 'neutral',
    emotionalStrain: false,
    emotionalStability: true,
    emotionalPatterns: <String>[],
  ),
  logs: const [],
  timeline: const [],
  memories: const [],
  notifications: const [],
  planPreview: const [],
  profile: ProfileState(),
  siState: const SIState(energy: .7, fatigue: .2),
  trajectory: _trajectory,
);

const TrajectorySummaryView _trajectory = TrajectorySummaryView(
  pendingTasks: 1,
  completedTasks: 0,
  completedToday: 0,
  level: 1,
  streak: 0,
  energy: .7,
  momentum: .5,
  adaptability: .5,
  lastCompletionXp: 0,
  lastCompletionQuality: 0,
  pressureIndex: 20,
  behaviorDivergence: 0,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);
