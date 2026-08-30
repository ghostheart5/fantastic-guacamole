import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 16, 12);

  test('snapshot identity is stable across observation times', () {
    final OperatingSnapshot first = _snapshot(now: now);
    final OperatingSnapshot second = _snapshot(
      now: now.add(const Duration(minutes: 3)),
    );
    expect(first.snapshotId, second.snapshotId);
  });

  test(
    'first observation establishes a baseline without fabricated changes',
    () {
      final OperatingDelta delta = const OperatingDeltaEngine().compare(
        previous: null,
        current: _snapshot(now: now),
        comparedAt: now,
      );
      expect(delta.isBaseline, isTrue);
      expect(delta.changes, isEmpty);
      expect(delta.summary, contains('Baseline established'));
    },
  );

  test(
    'material delta identifies priority, pressure, and completion changes',
    () {
      final OperatingSnapshot previous = _snapshot(now: now);
      final OperatingSnapshot current = _snapshot(
        now: now.add(const Duration(hours: 1)),
        topActionLabel: 'Ship release candidate',
        completedToday: 2,
        pressure: 70,
      );
      final OperatingDelta delta = const OperatingDeltaEngine().compare(
        previous: previous,
        current: current,
        comparedAt: current.observedAt,
      );
      expect(delta.isBaseline, isFalse);
      expect(
        delta.materialChanges.map((item) => item.kind),
        containsAll(<Object>[
          OperatingChangeKind.priority,
          OperatingChangeKind.momentum,
          OperatingChangeKind.progression,
          OperatingChangeKind.risk,
        ]),
      );
    },
  );

  test('decision receipt rejects action-to-subject divergence', () {
    final OperatingDecisionReceipt receipt = OperatingDecisionReceipt(
      subjectId: 'task-a',
      recommendedAction: 'Start task A',
      rationale: 'Task A ranks first.',
      whyItMatters: 'It protects the deadline.',
      consequenceOfDelay: 'Schedule pressure rises.',
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
      confidence: OperatingConfidence.high,
      evidence: const <OperatingEvidence>[],
      actionIntent: const OperatingActionIntent(
        id: 'action-b',
        type: OperatingActionType.openEntity,
        label: 'Open task B',
        destination: '/timeline',
        targetEntityId: 'task-b',
      ),
      sourceRevisions: const <String, String>{'tasks': '1'},
      modelVersion: 'test-v1',
    );
    expect(receipt.validate, throwsStateError);
  });

  test('receipt retains stable snapshot, plan, and decision identities', () {
    OperatingDecisionReceipt build() => OperatingDecisionReceipt(
      subjectId: 'task-a',
      recommendedAction: 'Start task A',
      rationale: 'Task A ranks first.',
      whyItMatters: 'It protects the deadline.',
      consequenceOfDelay: 'Schedule pressure rises.',
      generatedAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
      confidence: OperatingConfidence.high,
      evidence: const <OperatingEvidence>[],
      actionIntent: const OperatingActionIntent(
        id: 'action-a',
        type: OperatingActionType.openEntity,
        label: 'Open task A',
        destination: '/timeline',
        targetEntityId: 'task-a',
      ),
      sourceRevisions: const <String, String>{'tasks': 'revision-1'},
      modelVersion: 'decision-v1',
    );

    final OperatingDecisionReceipt first = build();
    final OperatingDecisionReceipt second = build();
    expect(first.snapshotId, second.snapshotId);
    expect(first.planId, second.planId);
    expect(first.decisionId, second.decisionId);
  });
}

OperatingSnapshot _snapshot({
  required DateTime now,
  String topActionLabel = 'Start task A',
  int completedToday = 0,
  int pressure = 40,
}) => OperatingSnapshot(
  accountScope: 'v2.test',
  observedAt: now,
  sourceRevisions: const <String, String>{'tasks': '1', 'goals': '1'},
  activeGoalCount: 1,
  actionableCount: 2,
  overdueCount: 0,
  completedToday: completedToday,
  energy: .7,
  fatigue: .2,
  momentum: completedToday > 0 ? 70 : 60,
  pressure: pressure,
  topActionId: topActionLabel == 'Start task A' ? 'task-a' : 'task-b',
  topActionLabel: topActionLabel,
  activeRisks: const <String>[],
  evidenceCoverage: 1,
);
