import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/application/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';

final DateTime trajectoryFixtureNow = DateTime.utc(2026, 8, 16, 15);

TrajectoryBaseline trajectoryTestBaseline({
  int momentum = 61,
  int pressure = 58,
  int observationCount = 12,
}) => TrajectoryBaseline(
  accountScope: 'v2.test-account',
  revision: 'trajectory-fixture-r1',
  observedAt: trajectoryFixtureNow,
  evidenceWindow: const Duration(days: 7),
  momentum: momentum,
  pressure: pressure,
  energy: 64,
  completedInWindow: 6,
  deferredInWindow: 3,
  observationCount: observationCount,
  availableMinutes: 420,
  occupiedMinutes: 300,
  unscheduledMinutes: 90,
  tasks: <TrajectoryTaskNode>[
    TrajectoryTaskNode(
      id: 'task-launch',
      title: 'Ship protected milestone',
      priority: 5,
      estimatedMinutes: 90,
      goalId: 'goal-release',
      dueAt: trajectoryFixtureNow.add(const Duration(days: 2)),
      scheduledAt: trajectoryFixtureNow.add(const Duration(days: 1)),
    ),
    const TrajectoryTaskNode(
      id: 'task-polish',
      title: 'Polish optional copy',
      priority: 1,
      estimatedMinutes: 60,
      goalId: 'goal-release',
    ),
  ],
  goals: <TrajectoryGoalNode>[
    TrajectoryGoalNode(
      id: 'goal-release',
      title: 'Release candidate',
      targetDate: trajectoryFixtureNow.add(const Duration(days: 4)),
      linkedTaskIds: const <String>['task-launch', 'task-polish'],
    ),
  ],
  blocks: <TrajectoryBlockNode>[
    TrajectoryBlockNode(
      id: 'block-launch',
      taskId: 'task-launch',
      start: trajectoryFixtureNow.add(const Duration(days: 1)),
      end: trajectoryFixtureNow.add(const Duration(days: 1, minutes: 90)),
    ),
  ],
  timelineSignals: <TrajectoryTimelineSignal>[
    TrajectoryTimelineSignal(
      id: 'signal-launch',
      relatedId: 'task-launch',
      dueAt: trajectoryFixtureNow.add(const Duration(days: 2)),
      isOverdue: false,
      isAtRisk: true,
    ),
  ],
  progression: const TrajectoryProgressionSnapshot(
    level: 3,
    xp: 420,
    streak: 6,
  ),
  confidence: const PredictiveConfidenceProfile(
    sourceCompleteness: .92,
    freshness: .95,
    sampleSufficiency: .75,
    intervalPrecision: .72,
  ),
  sourceRevisions: const <String, String>{
    'tasks': '2',
    'goals': '1',
    'timeline': '1',
    'plan': '1',
  },
);

TrajectoryComparison trajectoryTestComparison({int horizonDays = 7}) {
  final TrajectoryBaseline baseline = trajectoryTestBaseline();
  return const FutureConsequenceEngine().compare(
    baseline: baseline,
    generatedAt: trajectoryFixtureNow,
    interventions:
        <TrajectoryIntervention>[
              const TrajectoryIntervention(
                id: 'maintain',
                type: TrajectoryInterventionType.maintainCourse,
                title: 'Maintain current course',
                horizon: Duration(days: 7),
                description: 'Keep the present plan unchanged.',
              ),
              TrajectoryIntervention(
                id: 'planner',
                type: TrajectoryInterventionType.applySmartPlanner,
                title: 'Protect the Smart Planner path',
                horizon: const Duration(days: 7),
                description: 'Protect the highest-value feasible block.',
                subjectId: 'task-launch',
                proposedBlocks: <TrajectoryBlockNode>[
                  TrajectoryBlockNode(
                    id: 'block-launch',
                    taskId: 'task-launch',
                    start: trajectoryFixtureNow,
                    end: trajectoryFixtureNow.add(const Duration(minutes: 90)),
                  ),
                ],
                assumptions: <String>['The protected block is attempted.'],
              ),
              const TrajectoryIntervention(
                id: 'delay',
                type: TrajectoryInterventionType.delayTask,
                title: 'Delay the milestone',
                horizon: Duration(days: 7),
                description: 'Move the protected milestone by two days.',
                subjectId: 'task-launch',
                delay: Duration(days: 2),
              ),
            ]
            .map(
              (TrajectoryIntervention value) => TrajectoryIntervention(
                id: value.id,
                type: value.type,
                title: value.title,
                horizon: Duration(days: horizonDays),
                description: value.description,
                subjectId: value.subjectId,
                delay: value.delay,
                proposedBlocks: value.proposedBlocks,
                displacedSubjectIds: value.displacedSubjectIds,
                assumptions: value.assumptions,
              ),
            )
            .toList(growable: false),
  );
}

TrajectorySummaryView trajectoryTestSummary() => const TrajectorySummaryView(
  pendingTasks: 2,
  completedTasks: 6,
  completedToday: 1,
  level: 3,
  streak: 6,
  energy: .64,
  momentum: .61,
  adaptability: .7,
  lastCompletionXp: 20,
  lastCompletionQuality: .8,
  pressureIndex: 58,
  behaviorDivergence: 18,
  alert: 'A high-value deadline has limited slack.',
  sourceState: TrajectorySourceState.ready,
  riskBand: TrajectoryRiskBand.watch,
  statusDetail: 'Current evidence is reconciled.',
  predictionTitle: 'Ship protected milestone',
  predictionOutcome: 'Completion is plausible if the protected block holds.',
  predictionProbability: .72,
  predictionExplanation: 'Based on task-specific observed execution history.',
  predictionLowerBound: .54,
  predictionUpperBound: .84,
  predictionSampleSize: 12,
  predictionConfidence: PredictiveConfidenceProfile(
    sourceCompleteness: .9,
    freshness: .9,
    sampleSufficiency: .7,
    intervalPrecision: .7,
  ),
  predictionModelVersion: 'learning-task-v2',
);

const MomentumEngineState trajectoryTestMomentum = MomentumEngineState(
  score: 61,
  trend: 'Stable',
  recovery: 'Watch Load',
  forecast: 'Pressure is manageable if active scope remains bounded.',
  energyPercent: 64,
  pressurePercent: 58,
  streak: 6,
  completedToday: 1,
);

TrajectoryEngineModel trajectoryTestEngineModel({
  TrajectoryEngineStatus status = TrajectoryEngineStatus.ready,
}) => TrajectoryEngineModel(
  status: status,
  summary: trajectoryTestSummary(),
  momentum: trajectoryTestMomentum,
  comparison: trajectoryTestComparison(),
  statusDetail:
      'Current baseline, Smart Planner plan, Timeline links, goals, and Progression signals are reconciled.',
  isOnline: true,
);
