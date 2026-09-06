import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runtime scanners reject provider failures and preserve benign logs',
    () {
      final ProcessResult result = Process.runSync(
        Platform.isWindows ? 'powershell.exe' : 'pwsh',
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          'test/release/fixtures/android_runtime_fatal_scanner_fixture.ps1',
        ],
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final Map<String, dynamic> receipt =
          jsonDecode(result.stdout as String) as Map<String, dynamic>;
      expect(receipt['status'], 'passed');
      expect(receipt['passed'], 15);
      expect(receipt['failed'], 0);
    },
  );

  test('every maintained runtime scanner includes the shared diagnostics', () {
    for (final String name in <String>[
      'run_maestro_android_evidence.ps1',
      'run_android_monkey_matrix.ps1',
      'android_diagnose_one_click.ps1',
      'android_logcat_scan_latest.ps1',
      'strict_android_runtime_gate.ps1',
    ]) {
      final String source = File('scripts/$name').readAsStringSync();
      expect(source, contains("'android_runtime_fatal_patterns.ps1'"));
      expect(source, contains('+ @(Get-ChronoSparkFatalDiagnosticPatterns)'));
    }
  });
}
