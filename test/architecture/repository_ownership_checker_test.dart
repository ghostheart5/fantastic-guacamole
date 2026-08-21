import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('architecture checker accepts composite repository ownership', () async {
    final String powerShell = Platform.isWindows ? 'powershell' : 'pwsh';
    final List<String> arguments = <String>[
      '-NoProfile',
      if (Platform.isWindows) ...<String>['-ExecutionPolicy', 'Bypass'],
      '-File',
      'check_architecture.ps1',
    ];

    final ProcessResult result = await Process.run(
      powerShell,
      arguments,
      workingDirectory: Directory.current.path,
    );

    expect(
      result.exitCode,
      0,
      reason:
          'The architecture checker must accept repository interfaces owned '
          'through a concrete composite interface implementation.\n'
          'stdout:\n${result.stdout}\n'
          'stderr:\n${result.stderr}',
    );
  });
}
