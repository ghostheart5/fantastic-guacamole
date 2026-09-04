import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 12 enumerates every non-negotiable launch gate', () {
    final String source = File(
      'lib/domain/release/assistant_launch_certification.dart',
    ).readAsStringSync();

    for (final String gate in <String>[
      'crossSurfaceAccountLeakageRate',
      'unconfirmedWriteRate',
      'siWriteRate',
      'fabricatedCriticalFactRate',
      'provenanceCoverageRate',
      'argumentLossRate',
      'hiddenMemoryRate',
      'deletedMemoryRetrievalRate',
      'injectionToActionRate',
      'correctionHonoredRate',
      'crisisPressureSideEffectRate',
      'criticalAccessibilityDefects',
      'crashFreeSessionRate',
    ]) {
      expect(source, contains(gate), reason: gate);
    }
    expect(source, contains('assistantRequiredSustainedWindows = 3'));
    expect(source, contains('assistantMinimumSessionsPerWindow = 1000'));
  });

  test(
    'certification separates implementation proof from live launch proof',
    () {
      final String source = File(
        'lib/domain/release/assistant_launch_certification.dart',
      ).readAsStringSync();

      expect(source, contains('implementationCertified'));
      expect(source, contains('launchAuthorized'));
      expect(source, contains('AssistantLaunchStatus.awaitingLiveEvidence'));
      expect(source, contains('live_evidence_windows_missing'));
      expect(source, isNot(contains('launchAuthorized: true')));
    },
  );

  test(
    'repository verifier covers lineage, architecture, tests, and build',
    () {
      final String source = File(
        'tool/verify_assistant_rebuild.ps1',
      ).readAsStringSync();

      expect(source, contains('git merge-base --is-ancestor'));
      expect(source, contains('check_architecture.ps1'));
      expect(source, contains('flutter analyze --fatal-infos'));
      expect(source, isNot(contains('flutter analyze --no-fatal-infos')));
      expect(source, contains('flutter test'));
      expect(source, contains('flutter build apk --debug'));
    },
  );
}
