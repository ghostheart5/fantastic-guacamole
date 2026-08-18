import 'package:fantastic_guacamole/app/feature_canon.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/features/nexus/domain/nexus_briefing_model.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nexus action resolver', () {
    test('maps every operating action without a silent Timeline fallback', () {
      const Map<OperatingActionType, NexusActionDestination> expected =
          <OperatingActionType, NexusActionDestination>{
            OperatingActionType.openEntity: NexusActionDestination.siConsole,
            OperatingActionType.openCreator: NexusActionDestination.creator,
            OperatingActionType.openTimeline: NexusActionDestination.timeline,
            OperatingActionType.openSmartPlanner:
                NexusActionDestination.smartPlanner,
            OperatingActionType.openSiConsole: NexusActionDestination.siConsole,
            OperatingActionType.openTrajectoryEngine:
                NexusActionDestination.trajectoryEngine,
            OperatingActionType.openProgression:
                NexusActionDestination.progression,
            OperatingActionType.createTimelineBlock:
                NexusActionDestination.timeline,
            OperatingActionType.rescheduleCommitment:
                NexusActionDestination.timeline,
            OperatingActionType.reprioritizeGoal:
                NexusActionDestination.smartPlanner,
            OperatingActionType.acknowledgeBriefing:
                NexusActionDestination.acknowledge,
            OperatingActionType.none: NexusActionDestination.none,
          };

      for (final MapEntry<OperatingActionType, NexusActionDestination> entry
          in expected.entries) {
        final String destination = entry.key == OperatingActionType.openEntity
            ? RoutePaths.siConsole
            : RoutePaths.nexus;
        expect(
          NexusActionResolver.resolve(
            OperatingActionIntent(
              id: entry.key.name,
              type: entry.key,
              label: entry.key.name,
              destination: destination,
            ),
          ),
          entry.value,
          reason: 'Incorrect resolution for ${entry.key.name}',
        );
      }
    });

    test('rejects an unknown entity route instead of opening Timeline', () {
      expect(
        NexusActionResolver.resolve(
          const OperatingActionIntent(
            id: 'unknown',
            type: OperatingActionType.openEntity,
            label: 'Unknown',
            destination: '/not-canonical',
          ),
        ),
        NexusActionDestination.unsupported,
      );
    });
  });

  group('Nexus planning-summary states', () {
    testWidgets('loading and error states are explicit and recoverable', (
      WidgetTester tester,
    ) async {
      await _pumpSection(
        tester,
        _model(status: NexusBriefingStatus.loading),
      );
      expect(find.text('PREPARING YOUR SUMMARY'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      int retries = 0;
      await _pumpSection(
        tester,
        _model(
          status: NexusBriefingStatus.error,
          detail: 'Your planning summary is unavailable.',
        ),
        onRetry: () => retries++,
      );
      expect(find.text('NEXUS RECOVERY'), findsOneWidget);
      await tester.tap(find.text('Retry Nexus'));
      expect(retries, 1);
    });

    testWidgets(
      'offline state keeps the local briefing and discloses freshness',
      (WidgetTester tester) async {
        await _pumpSection(
          tester,
          _model(
            status: NexusBriefingStatus.offline,
            briefing: _briefing(),
            detail: 'Using local evidence. 2 changes will synchronize later.',
          ),
        );
        expect(find.textContaining('OFFLINE:'), findsOneWidget);
        expect(find.text('WHAT MATTERS NEXT'), findsOneWidget);
        expect(find.text('TOP RISK'), findsOneWidget);
      },
    );

    testWidgets('empty state routes authority through the briefing action', (
      WidgetTester tester,
    ) async {
      int actions = 0;
      await _pumpSection(
        tester,
        _model(
          status: NexusBriefingStatus.ready,
          briefing: _briefing(empty: true),
        ),
        onAction: (_) => actions++,
      );
      expect(find.textContaining('Start in Creator'), findsOneWidget);
      await tester.tap(find.text('Open Creator'));
      expect(actions, 1);
    });

    testWidgets(
      'feature mesh exposes all and only canonical connected features',
      (WidgetTester tester) async {
        final NexusBriefingModel model = _model(
          status: NexusBriefingStatus.ready,
          briefing: _briefing(),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: NexusFeatureSignalMesh(model: model),
              ),
            ),
          ),
        );
        for (final String label in <String>[
          'SMART PLANNER',
          'CREATOR',
          'TIMELINE',
          'TRAJECTORY ENGINE',
          'PROGRESSION',
          'SI CONSOLE',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('ASCENSION'), findsNothing);
        expect(find.text('INSIGHTS'), findsNothing);
        expect(find.text('SESSION'), findsNothing);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Smart Planner\. READY\. smartPlanner headline'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}

Future<void> _pumpSection(
  WidgetTester tester,
  NexusBriefingModel model, {
  VoidCallback? onRetry,
  ValueChanged<OperatingActionIntent>? onAction,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NexusCommandSection(
            model: model,
            onRetry: onRetry ?? () {},
            onAction: onAction ?? (_) {},
            onAcknowledge: () {},
          ),
        ),
      ),
    ),
  );
}

NexusBriefingModel _model({
  required NexusBriefingStatus status,
  OperatingBriefing? briefing,
  String detail = 'Building one evidence-backed operating decision.',
}) {
  return NexusBriefingModel(
    status: status,
    isOnline: status != NexusBriefingStatus.offline,
    pendingSyncCount: status == NexusBriefingStatus.offline ? 2 : 0,
    briefing: briefing,
    featureSignals: <NexusFeatureSignal>[
      for (final ChronoSparkFeatureId id in <ChronoSparkFeatureId>[
        ChronoSparkFeatureId.smartPlanner,
        ChronoSparkFeatureId.creator,
        ChronoSparkFeatureId.timeline,
        ChronoSparkFeatureId.trajectoryEngine,
        ChronoSparkFeatureId.progression,
        ChronoSparkFeatureId.siConsole,
      ])
        NexusFeatureSignal(
          featureId: id,
          health: NexusFeatureHealth.ready,
          headline: '${id.name} headline',
          detail: '${id.name} detail',
          revision: '${id.name}:1',
        ),
    ],
    topRisk: 'One overdue commitment needs recovery.',
    recentProgress: 'Completion increased from 0 to 1.',
    statusDetail: detail,
  );
}

OperatingBriefing _briefing({bool empty = false}) {
  final DateTime now = DateTime.utc(2026, 8, 16, 12);
  final OperatingSnapshot snapshot = OperatingSnapshot(
    accountScope: 'v2.nexus-test',
    observedAt: now,
    sourceRevisions: const <String, String>{'tasks': '1'},
    activeGoalCount: empty ? 0 : 1,
    actionableCount: empty ? 0 : 2,
    overdueCount: empty ? 0 : 1,
    completedToday: empty ? 0 : 1,
    energy: .7,
    fatigue: .2,
    momentum: 65,
    pressure: 55,
    topActionId: empty ? null : 'task-a',
    topActionLabel: empty ? 'Capture one high-value task.' : 'Start task A',
    activeRisks: empty
        ? const <String>[]
        : const <String>['One overdue commitment needs recovery.'],
    evidenceCoverage: .9,
  );
  final OperatingDecisionReceipt decision = OperatingDecisionReceipt(
    subjectId: empty ? null : 'task-a',
    recommendedAction: empty ? 'Capture one high-value task.' : 'Start task A',
    rationale: empty
        ? 'Nexus needs one accountable input.'
        : 'Task A ranks first.',
    whyItMatters: 'It closes the most important evidence gap.',
    consequenceOfDelay: 'Pressure can rise.',
    generatedAt: now,
    expiresAt: now.add(const Duration(days: 3650)),
    confidence: OperatingConfidence.high,
    evidence: const <OperatingEvidence>[],
    actionIntent: OperatingActionIntent(
      id: empty ? 'open-creator' : 'open-timeline',
      type: empty
          ? OperatingActionType.openCreator
          : OperatingActionType.openTimeline,
      label: empty ? 'Open Creator' : 'Review on Timeline',
      destination: empty ? RoutePaths.creator : RoutePaths.timeline,
      targetEntityId: empty ? null : 'task-a',
    ),
    sourceRevisions: const <String, String>{'tasks': '1'},
    modelVersion: 'nexus-test-v1',
    warnings: snapshot.activeRisks,
  );
  return OperatingBriefing(
    snapshot: snapshot,
    delta: const OperatingDeltaEngine().compare(
      previous: null,
      current: snapshot,
      comparedAt: null,
    ),
    decision: decision,
    acknowledgedSnapshotId: null,
  );
}
