import 'package:fantastic_guacamole/domain/release/assistant_launch_certification.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<AssistantPhaseEvidence> phases() {
    return AssistantRebuildPhase.values.indexed
        .map(
          ((int, AssistantRebuildPhase) item) => AssistantPhaseEvidence(
            phase: item.$2,
            commitSha: (item.$1 + 1).toRadixString(16).padLeft(7, '0'),
            artifactIds: <String>['phase-${item.$1 + 1}-verification'],
            verified: true,
          ),
        )
        .toList(growable: true);
  }

  const AssistantBuildVerification build = AssistantBuildVerification(
    staticAnalysisPassed: true,
    architecturePassed: true,
    fullTestSuitePassed: true,
    debugBuildPassed: true,
    fullTestCount: 1200,
    sourceHeadSha: 'abcdef1',
  );

  Map<AssistantLaunchGateId, double> passingMetrics() {
    return <AssistantLaunchGateId, double>{
      for (final AssistantLaunchGateId gate in AssistantLaunchGateId.values)
        gate: switch (gate) {
          AssistantLaunchGateId.provenanceCoverageRate => 0.995,
          AssistantLaunchGateId.correctionHonoredRate => 1,
          AssistantLaunchGateId.crashFreeSessionRate => 0.9995,
          _ => 0,
        },
    };
  }

  AssistantLaunchEvidenceWindow window(
    int day, {
    Map<AssistantLaunchGateId, double>? metrics,
    int sessions = assistantMinimumSessionsPerWindow,
  }) {
    final DateTime start = DateTime.utc(2026, 8, day);
    return AssistantLaunchEvidenceWindow(
      windowId: 'window-$day',
      startsAt: start,
      endsAt: start.add(const Duration(days: 1)),
      sessionCount: sessions,
      observedMetrics: metrics ?? passingMetrics(),
      evidenceIds: <AssistantLaunchGateId, Iterable<String>>{
        for (final AssistantLaunchGateId gate in AssistantLaunchGateId.values)
          gate: <String>['aggregate-${gate.name}-$day'],
      },
    );
  }

  AssistantLaunchCertificationResult evaluate({
    List<AssistantPhaseEvidence>? phaseEvidence,
    AssistantBuildVerification buildVerification = build,
    Iterable<AssistantReleaseCapability>? rollbackCapabilities,
    Iterable<AssistantLaunchEvidenceWindow>? windows,
  }) {
    return const AssistantLaunchCertification().evaluate(
      phaseEvidence: phaseEvidence ?? phases(),
      buildVerification: buildVerification,
      independentlyRollbackableCapabilities:
          rollbackCapabilities ?? AssistantReleaseCapability.values,
      liveWindows:
          windows ??
          <AssistantLaunchEvidenceWindow>[window(1), window(2), window(3)],
    );
  }

  test('authorizes only complete implementation and three passing windows', () {
    final AssistantLaunchCertificationResult result = evaluate();

    expect(result.status, AssistantLaunchStatus.authorized);
    expect(result.implementationCertified, isTrue);
    expect(result.launchAuthorized, isTrue);
    expect(result.findingCodes, isEmpty);
    expect(result.failedGates, isEmpty);
    expect(result.receiptDigest, hasLength(64));
  });

  test('certifies implementation but awaits absent live evidence', () {
    final AssistantLaunchCertificationResult result = evaluate(
      windows: const <AssistantLaunchEvidenceWindow>[],
    );

    expect(result.status, AssistantLaunchStatus.awaitingLiveEvidence);
    expect(result.implementationCertified, isTrue);
    expect(result.launchAuthorized, isFalse);
    expect(result.findingCodes, contains('live_evidence_windows_missing'));
  });

  test('every launch threshold independently blocks authorization', () {
    for (final AssistantLaunchGateId gate in AssistantLaunchGateId.values) {
      final Map<AssistantLaunchGateId, double> metrics = passingMetrics();
      metrics[gate] = switch (assistantLaunchThresholds[gate]!.direction) {
        AssistantLaunchThresholdDirection.maximum =>
          assistantLaunchThresholds[gate]!.value + 0.001,
        AssistantLaunchThresholdDirection.minimum =>
          assistantLaunchThresholds[gate]!.value - 0.001,
      };
      final AssistantLaunchCertificationResult result = evaluate(
        windows: <AssistantLaunchEvidenceWindow>[
          window(1),
          window(2),
          window(3, metrics: metrics),
        ],
      );

      expect(result.status, AssistantLaunchStatus.liveEvidenceRejected);
      expect(result.launchAuthorized, isFalse);
      expect(result.failedGates, contains(gate), reason: gate.name);
    }
  });

  test('missing phase evidence rejects implementation', () {
    final List<AssistantPhaseEvidence> incomplete = phases()..removeLast();
    final AssistantLaunchCertificationResult result = evaluate(
      phaseEvidence: incomplete,
    );

    expect(result.status, AssistantLaunchStatus.implementationRejected);
    expect(result.implementationCertified, isFalse);
    expect(result.findingCodes, contains('phase_evidence_incomplete'));
  });

  test('all four independent rollback switches are mandatory', () {
    final AssistantLaunchCertificationResult result = evaluate(
      rollbackCapabilities: AssistantReleaseCapability.values.where(
        (AssistantReleaseCapability capability) =>
            capability != AssistantReleaseCapability.safetyCritic,
      ),
    );

    expect(result.status, AssistantLaunchStatus.implementationRejected);
    expect(result.findingCodes, contains('independent_rollback_incomplete'));
  });

  test('undersized or overlapping windows reject live evidence', () {
    final AssistantLaunchEvidenceWindow overlapping =
        AssistantLaunchEvidenceWindow(
          windowId: 'overlap',
          startsAt: DateTime.utc(2026, 8, 2, 12),
          endsAt: DateTime.utc(2026, 8, 3, 12),
          sessionCount: assistantMinimumSessionsPerWindow - 1,
          observedMetrics: passingMetrics(),
          evidenceIds: <AssistantLaunchGateId, Iterable<String>>{
            for (final AssistantLaunchGateId gate
                in AssistantLaunchGateId.values)
              gate: <String>['evidence-${gate.name}'],
          },
        );
    final AssistantLaunchCertificationResult result = evaluate(
      windows: <AssistantLaunchEvidenceWindow>[
        window(1),
        window(2),
        overlapping,
      ],
    );

    expect(result.status, AssistantLaunchStatus.liveEvidenceRejected);
    expect(
      result.findingCodes.any(
        (String item) => item.contains('insufficient_window_sessions'),
      ),
      isTrue,
    );
    expect(
      result.findingCodes.any(
        (String item) => item.contains('overlapping_evidence_window'),
      ),
      isTrue,
    );
  });
}
