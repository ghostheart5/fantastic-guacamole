import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/ui/widgets/decision_intelligence_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('intelligence visibly answers all four decision questions', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 16, 12);
    final OperatingSnapshot snapshot = OperatingSnapshot(
      accountScope: 'v2.test',
      observedAt: now,
      sourceRevisions: const <String, String>{'tasks': '1'},
      activeGoalCount: 1,
      actionableCount: 2,
      overdueCount: 1,
      completedToday: 1,
      energy: .7,
      fatigue: .2,
      momentum: 65,
      pressure: 55,
      topActionId: 'task-a',
      topActionLabel: 'Start task A',
      activeRisks: const <String>['One overdue task'],
      evidenceCoverage: 1,
    );
    final OperatingDecisionReceipt decision = OperatingDecisionReceipt(
      subjectId: 'task-a',
      recommendedAction: 'Start task A',
      rationale: 'Task A ranks first.',
      whyItMatters: 'It protects the deadline.',
      consequenceOfDelay: 'Pressure rises.',
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
      confidence: OperatingConfidence.high,
      evidence: const <OperatingEvidence>[],
      actionIntent: const OperatingActionIntent(
        id: 'action-a',
        type: OperatingActionType.openTimeline,
        label: 'Review on Timeline',
        destination: '/timeline',
        targetEntityId: 'task-a',
      ),
      sourceRevisions: const <String, String>{'tasks': '1'},
      modelVersion: 'test-v1',
    );
    final DecisionIntelligence intelligence = DecisionIntelligence(
      snapshot: snapshot,
      delta: const OperatingDeltaEngine().compare(
        previous: null,
        current: snapshot,
        comparedAt: now,
      ),
      decision: decision,
      acknowledgedSnapshotId: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DecisionIntelligenceCard(
              intelligence: intelligence,
              topRisk: 'One overdue task',
              recentProgress: 'One task completed since the last intelligence.',
              onAction: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('WHERE YOU ARE'), findsOneWidget);
    expect(find.text('WHAT CHANGED'), findsOneWidget);
    expect(find.text('WHAT MATTERS NEXT'), findsOneWidget);
    expect(find.text('WHY THIS MATTERS'), findsOneWidget);
    expect(find.text('TOP RISK'), findsOneWidget);
    expect(find.text('One overdue task'), findsOneWidget);
    expect(
      find.text('One task completed since the last intelligence.'),
      findsOneWidget,
    );
    expect(find.text('Start task A'), findsOneWidget);
    expect(find.text('Review on Timeline'), findsOneWidget);
  });
}
