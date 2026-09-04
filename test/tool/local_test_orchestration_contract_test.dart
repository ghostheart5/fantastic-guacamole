import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String strictGate = File('scripts/strict_gate.ps1').readAsStringSync();
  final String androidRuntimeGate = File(
    'scripts/strict_android_runtime_gate.ps1',
  ).readAsStringSync();
  final String runAllTests = File('run-all-tests.ps1').readAsStringSync();
  final String prePushHook = File('.githooks/pre-push').readAsStringSync();

  test(
    'strict gate routes every Flutter test category through the wrapper',
    () {
      expect(
        strictGate,
        isNot(contains(RegExp(r'^\s*flutter\s+test\b', multiLine: true))),
      );
      expect(strictGate, contains('dart run tool/run_flutter_tests.dart'));
      expect(strictGate, contains("-Label 'host-coverage'"));
      expect(strictGate, contains("-Label 'host'"));
      expect(strictGate, contains("-Label 'integration'"));
      expect(strictGate, contains(r'--timeout-seconds $TimeoutSeconds'));
      expect(strictGate, contains('--allowed-skips 0'));
    },
  );

  test('strict gate reports omitted or not-run required stages as partial', () {
    expect(
      strictGate,
      contains("-PartialExitCodes @(2)"),
      reason: 'Android child not-run must be mapped rather than marked PASS.',
    );
    expect(strictGate, contains(r'overallResult = $OverallResult'));
    expect(strictGate, contains(r'exitCode = $ExitCode'));
    expect(strictGate, contains('function Write-GateManifest'));
    expect(strictGate, contains("-OverallResult 'FAIL' -ExitCode 1"));
    expect(strictGate, contains("'PARTIAL'"));
    expect(strictGate, contains("'COMPLETE'"));
    expect(strictGate, contains('exit 2'));
  });

  test(
    'pre-push permits only unselected stages, not requested not-run work',
    () {
      expect(prePushHook, contains('-AllowUnselectedStages'));
      expect(strictGate, contains('[switch]\$AllowUnselectedStages'));
      expect(
        strictGate,
        contains(r'$partialStageCount -eq 0 -and $AllowUnselectedStages'),
      );
      expect(strictGate, contains('PARTIAL SOURCE CHECK'));
    },
  );

  test('Android runtime gate distinguishes not-run from pass and failure', () {
    expect(androidRuntimeGate, contains(r'$notRunExitCode = 2'));
    expect(
      RegExp(r'exit \$notRunExitCode').allMatches(androidRuntimeGate),
      hasLength(3),
    );
    expect(androidRuntimeGate, contains(r'if ($RequireDevice)'));
    expect(androidRuntimeGate, contains('exit 1'));
    expect(androidRuntimeGate, contains('STRICT ANDROID RUNTIME GATE PASSED'));
  });

  test('run-all keeps its result semantics and uses bounded test evidence', () {
    expect(runAllTests, isNot(contains(r"$flutter @('test'")));
    expect(
      'tool\\run_flutter_tests.dart'.allMatches(runAllTests),
      hasLength(2),
    );
    expect("'--allowed-skips','0'".allMatches(runAllTests), hasLength(2));
    expect("'--timeout-seconds','3600'".allMatches(runAllTests), hasLength(2));
    expect(runAllTests, contains("if (\$failed.Count -gt 0)"));
    expect(runAllTests, contains("\$script:OverallStatus = 'failed'"));
    expect(runAllTests, contains('\$script:FinalExitCode = 1'));
    expect(runAllTests, contains("if (\$notRun.Count -gt 0)"));
    expect(runAllTests, contains("\$script:OverallStatus = 'partial'"));
    expect(runAllTests, contains('\$script:FinalExitCode = 2'));
    expect(runAllTests, contains('Overall result: PASS.'));
    expect(runAllTests, contains('function Write-OrchestratorManifest'));
    expect(runAllTests, contains("'orchestrator-manifest.json'"));
    expect(runAllTests, contains(r'status = $script:OverallStatus'));
    expect(runAllTests, contains(r'exitCode = $script:FinalExitCode'));
    expect(runAllTests, contains(r'stages = @($script:Results)'));
    expect(runAllTests, contains(r'error = $script:UnhandledError'));
    expect(runAllTests, contains('yyyyMMdd-HHmmssfff'));
    expect(runAllTests, contains(r'+ "-$PID")'));
  });
}
