import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late String runnerPath;
  late String powerShellExecutable;

  setUpAll(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chronospark-maestro-junit-',
    );
    runnerPath = File('scripts/run_maestro_android_evidence.ps1').absolute.path;
    powerShellExecutable = Platform.isWindows ? 'powershell.exe' : 'pwsh';
  });

  tearDownAll(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  ProcessResult validate(String fileName, {String? xml}) {
    final File fixture = File('${temporaryDirectory.path}/$fileName');
    if (xml != null) {
      fixture.writeAsStringSync(xml);
    }
    return Process.runSync(powerShellExecutable, <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      runnerPath,
      '-ValidateJUnitOnlyPath',
      fixture.path,
    ]);
  }

  Map<String, dynamic> output(ProcessResult result) {
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  String psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  ProcessResult runHelperFixture(String fileName, String body) {
    final File script = File('${temporaryDirectory.path}/$fileName.ps1');
    // Windows PowerShell 5.1 needs a BOM to decode UTF-8 fixture source.
    script.writeAsStringSync('''\ufeff
\$ErrorActionPreference = 'Stop'
. ${psLiteral(runnerPath)}
$body
''');
    return Process.runSync(powerShellExecutable, <String>[
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
    ]);
  }

  test('records an empty branch for a real detached source snapshot', () {
    final Directory repository = Directory(
      '${temporaryDirectory.path}/detached-fixture',
    )..createSync();
    final ProcessResult result = runHelperFixture('detached-head', '''
\$fixtureRepository = ${psLiteral(repository.path)}
& git -C \$fixtureRepository init --quiet
if (\$LASTEXITCODE -ne 0) { throw 'Fixture init failed.' }
& git -C \$fixtureRepository -c user.name=ChronoSparkFixture -c user.email=fixture@example.invalid commit --quiet --allow-empty -m fixture
if (\$LASTEXITCODE -ne 0) { throw 'Fixture commit failed.' }
& git -C \$fixtureRepository checkout --quiet --detach
if (\$LASTEXITCODE -ne 0) { throw 'Fixture detach failed.' }
[ordered]@{
  branch = Get-GitEvidenceText -RepositoryRoot \$fixtureRepository -Arguments @('branch', '--show-current')
  commit = Get-GitEvidenceText -RepositoryRoot \$fixtureRepository -Arguments @('rev-parse', 'HEAD')
} | ConvertTo-Json -Compress
''');
    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(output(result)['branch'], '');
    expect(output(result)['commit'], matches(RegExp(r'^[a-f0-9]{40}$')));
  });

  test('native launcher uses the selected PowerShell working directory', () {
    final Directory selectedDirectory = Directory(
      '${temporaryDirectory.path}/selected source',
    )..createSync();
    File('${selectedDirectory.path}/relative-probe.ps1').writeAsStringSync('''
[Console]::Out.WriteLine((Get-Content -LiteralPath 'source-marker.txt' -Raw))
exit 0
''');
    File(
      '${selectedDirectory.path}/source-marker.txt',
    ).writeAsStringSync('selected checkout');
    final File log = File('${temporaryDirectory.path}/working-directory.log');
    final ProcessResult result = runHelperFixture('working-directory', '''
[Environment]::CurrentDirectory = ${psLiteral(temporaryDirectory.path)}
Set-Location -LiteralPath ${psLiteral(selectedDirectory.path)}
if ([Environment]::CurrentDirectory -eq (Get-Location).ProviderPath) { throw 'Fixture must have distinct process and PowerShell directories.' }
Invoke-NativeTimedLogged -Executable (Get-Process -Id \$PID).Path -Arguments @('-NoProfile', '-NonInteractive', '-File', 'relative-probe.ps1') -LogPath ${psLiteral(log.path)} -TimeoutSeconds 30 | ConvertTo-Json -Compress -Depth 4
''');
    expect(result.exitCode, 0, reason: result.stderr as String);
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['ExitCode'], 0, reason: receipt.toString());
    expect(receipt['TimedOut'], isFalse);
    expect(receipt['Output'], <String>['selected checkout']);
    expect(receipt['ErrorOutput'], isEmpty);
  });

  test('keeps native stderr in the log but out of parsed device output', () {
    final File probe = File('${temporaryDirectory.path}/native-probe.ps1')
      ..writeAsStringSync('''
[Console]::Out.WriteLine('35')
[Console]::Error.WriteLine('#< CLIXML diagnostic from native stderr')
exit 7
''');
    final File log = File('${temporaryDirectory.path}/native-probe.log');
    final ProcessResult result = runHelperFixture('native-output', '''
Invoke-NativeTimedLogged -Executable (Get-Process -Id \$PID).Path -Arguments @('-NoProfile', '-NonInteractive', '-File', ${psLiteral(probe.path)}) -LogPath ${psLiteral(log.path)} -TimeoutSeconds 30 | ConvertTo-Json -Compress -Depth 4
''');
    expect(result.exitCode, 0, reason: result.stderr as String);
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['ExitCode'], 7);
    expect(receipt['TimedOut'], isFalse);
    expect(receipt['Output'], <String>['35']);
    expect(
      (receipt['ErrorOutput'] as List<dynamic>).join('\n'),
      contains('diagnostic from native stderr'),
    );
    expect(log.readAsStringSync(), contains('35'));
    expect(log.readAsStringSync(), contains('diagnostic from native stderr'));
  });

  test(
    'native launcher sends data to a fixed entry without generated code',
    () {
      final String runner = File(runnerPath).readAsStringSync();
      final String entry = File(
        'scripts/native_command_entry.ps1',
      ).readAsStringSync();
      expect(runner, contains('native_command_entry.ps1'));
      expect(runner, contains('-NoProfile -NonInteractive -File'));
      expect(runner, contains(r'$startInfo.RedirectStandardInput = $true'));
      expect(
        runner,
        contains(r'$process.StandardInput.BaseStream.WriteAsync($payloadBytes'),
      );
      expect(entry, contains('[Console]::OpenStandardInput()'));
      expect(entry, contains(r'$payload = $payloadJson | ConvertFrom-Json'));
      expect(entry, contains(r'& $target @targetArguments'));
      for (final String source in <String>[runner, entry]) {
        expect(source, isNot(contains('-EncodedCommand')));
        expect(source, isNot(contains('FromBase64String')));
        expect(source, isNot(contains('Invoke-Expression')));
        expect(source, isNot(contains('[ScriptBlock]::Create')));
      }
    },
  );

  test(
    'native launcher accepts a UTF-8 host preamble and preserves Unicode',
    () {
      const String value = 'caf\u00e9 \u03a9 \u6f22 \u{1f680}';
      final File probe = File('${temporaryDirectory.path}/utf8-host-probe.ps1')
        ..writeAsStringSync('''\ufeff
if (\$args.Count -ne 1 -or \$args[0] -cne ${psLiteral(value)}) { exit 31 }
[Console]::Out.WriteLine('unicode survived')
exit 0
''');
      final File log = File('${temporaryDirectory.path}/utf8-host.log');
      final ProcessResult result = runHelperFixture('utf8-host', '''
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new(\$true)
Invoke-NativeTimedLogged -Executable (Get-Process -Id \$PID).Path -Arguments @('-NoProfile', '-NonInteractive', '-File', ${psLiteral(probe.path)}, ${psLiteral(value)}) -LogPath ${psLiteral(log.path)} -TimeoutSeconds 30 | ConvertTo-Json -Compress -Depth 4
''');
      expect(result.exitCode, 0, reason: result.stderr as String);
      final Map<String, dynamic> receipt = output(result);
      expect(receipt['ExitCode'], 0, reason: receipt.toString());
      expect(receipt['TimedOut'], isFalse);
      expect(receipt['Output'], <String>['unicode survived']);
      expect(receipt['ErrorOutput'], isEmpty);
    },
  );

  test(
    'native launcher preserves eleven long paths and literal metacharacters',
    () {
      final File probe = File('${temporaryDirectory.path}/native arguments.ps1')
        ..writeAsStringSync(r'''
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Values)
[Console]::Out.WriteLine((ConvertTo-Json -InputObject @($Values) -Compress))
[Console]::Error.WriteLine('long argv stderr preserved')
exit 23
''');
      final File sentinel = File(
        '${temporaryDirectory.path}/must-not-exist.txt',
      );
      final String longDirectory = List<String>.filled(
        12,
        'long directory',
      ).join('/');
      final List<String> arguments = <String>[
        for (int index = 0; index < 11; index++)
          '${temporaryDirectory.path}/$longDirectory/flow-$index.yaml',
        r'$(Write-Output unexpected-evaluation)',
        r'back`tick;semicolon&and|pipe>redirect<in',
        "apostrophe's literal value",
        'literal & echo unexpected > ${sentinel.path}',
      ];
      final File log = File('${temporaryDirectory.path}/long-argv.log');
      final ProcessResult result = runHelperFixture('native-long-argv', '''
Invoke-NativeTimedLogged -Executable (Get-Process -Id \$PID).Path -Arguments @('-NoProfile', '-NonInteractive', '-File', ${psLiteral(probe.path)}, ${arguments.map(psLiteral).join(', ')}) -LogPath ${psLiteral(log.path)} -TimeoutSeconds 30 | ConvertTo-Json -Compress -Depth 5
''');
      expect(result.exitCode, 0, reason: result.stderr as String);
      final Map<String, dynamic> receipt = output(result);
      expect(receipt['ExitCode'], 23, reason: receipt.toString());
      expect(receipt['TimedOut'], isFalse);
      final List<dynamic> stdout = receipt['Output'] as List<dynamic>;
      expect(stdout, hasLength(1));
      expect(jsonDecode(stdout.single as String), arguments);
      expect(
        (receipt['ErrorOutput'] as List<dynamic>).join('\n'),
        contains('long argv stderr preserved'),
      );
      expect(sentinel.existsSync(), isFalse);
    },
  );

  test('native launcher still terminates a command after its deadline', () {
    final File probe =
        File('${temporaryDirectory.path}/native-timeout-probe.ps1')
          ..writeAsStringSync(
            "[Console]::Out.WriteLine('started')\nStart-Sleep -Seconds 30\n",
          );
    final File log = File('${temporaryDirectory.path}/native-timeout.log');
    final ProcessResult result = runHelperFixture('native-timeout', '''
Invoke-NativeTimedLogged -Executable (Get-Process -Id \$PID).Path -Arguments @('-NoProfile', '-NonInteractive', '-File', ${psLiteral(probe.path)}) -LogPath ${psLiteral(log.path)} -TimeoutSeconds 2 | ConvertTo-Json -Compress -Depth 4
''');
    expect(result.exitCode, 0, reason: result.stderr as String);
    final Map<String, dynamic> receipt = output(result);
    expect(receipt['TimedOut'], isTrue, reason: receipt.toString());
    expect(receipt['ExitCode'], -1);
    expect(receipt['Output'], <String>['started']);
  });

  // cmd.exe batch semantics are exercised explicitly by the Windows CI lane.
  // Do not register an inapplicable skipped test in the Linux host suite.
  if (Platform.isWindows) {
    test('Windows batch wrapper preserves the actual eleven-flow argument shape', () {
      final File probe = File('${temporaryDirectory.path}/batch argv probe.ps1')
        ..writeAsStringSync(r'''
[Console]::Out.WriteLine((ConvertTo-Json -InputObject @($args) -Compress))
[Console]::Error.WriteLine('batch stderr preserved')
exit 29
''');
      final String host =
          '${Platform.environment['SystemRoot']}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
      final File batch = File('${temporaryDirectory.path}/fixture cli.bat')
        ..writeAsStringSync(
          '@echo off\r\n"$host" -NoProfile -NonInteractive -File "${probe.path}" %*\r\nexit /b %ERRORLEVEL%\r\n',
        );
      final File wrapper = File('${temporaryDirectory.path}/fixture.cmd')
        ..writeAsStringSync(
          '@echo off\r\ncall "${batch.path}" %*\r\nexit /b %ERRORLEVEL%\r\n',
        );
      final String artifactDirectory =
          '${temporaryDirectory.path}/source snapshot/artifacts/maestro/qa journeys';
      final List<String> arguments = <String>[
        '--device',
        'emulator-5554',
        '--verbose',
        'test',
        '--format',
        'junit',
        '--output',
        '$artifactDirectory/junit.xml',
        '--test-output-dir',
        artifactDirectory,
        '--debug-output',
        '$artifactDirectory/debug',
        '--config',
        '$artifactDirectory/maestro-sequence-config.yaml',
        for (int index = 0; index < 11; index++)
          '${temporaryDirectory.path}/source snapshot/.maestro/flows/long-journey-flow-$index.yaml',
      ];
      final File log = File('${temporaryDirectory.path}/batch-argv.log');
      final ProcessResult result = runHelperFixture('batch-argv', '''
Invoke-NativeTimedLogged -Executable ${psLiteral(wrapper.path)} -Arguments @(${arguments.map(psLiteral).join(', ')}) -LogPath ${psLiteral(log.path)} -TimeoutSeconds 30 | ConvertTo-Json -Compress -Depth 5
''');
      expect(result.exitCode, 0, reason: result.stderr as String);
      final Map<String, dynamic> receipt = output(result);
      expect(receipt['ExitCode'], 29, reason: receipt.toString());
      expect(receipt['TimedOut'], isFalse);
      final List<dynamic> stdout = receipt['Output'] as List<dynamic>;
      expect(stdout, hasLength(1));
      expect(jsonDecode(stdout.single as String), arguments);
      expect(
        (receipt['ErrorOutput'] as List<dynamic>).join('\n'),
        contains('batch stderr preserved'),
      );
    });
  }

  test('a failed Git lookup is not recorded as an empty branch', () {
    final ProcessResult result = runHelperFixture('invalid-git', '''
Get-GitEvidenceText -RepositoryRoot ${psLiteral(temporaryDirectory.path)} -Arguments @('rev-parse', 'definitely-not-a-revision')
''');
    expect(result.exitCode, isNonZero);
    expect(result.stderr as String, contains('Git evidence lookup failed'));
  });

  test('QA journey ordering preserves the lifecycle for its readback', () {
    final ProcessResult result = runHelperFixture('qa-order', '''
@(Get-SelectedFlows -SelectedSuite 'qa-journeys') | ConvertTo-Json -Compress
''');
    expect(result.exitCode, 0, reason: result.stderr as String);
    final List<dynamic> flows = jsonDecode(result.stdout as String) as List;
    expect(flows, hasLength(11));
    expect(flows.sublist(flows.length - 2), <String>[
      '.maestro/flows/priority8-learned-lifecycle.yaml',
      '.maestro/flows/priority8-learned-lifecycle-readback.yaml',
    ]);
    for (final dynamic path in flows) {
      expect(File(path as String).existsSync(), isTrue, reason: path);
    }
  });

  test('QA account journeys reject physical devices and production profiles', () {
    for (final (String, String) target in <(String, String)>[
      ('qa', '192.0.2.10:12345'),
      ('release', 'emulator-5554'),
    ]) {
      final ProcessResult result = runHelperFixture(
        'qa-target-${target.$1}',
        "Assert-QAJourneyTarget -Profile '${target.$1}' -Serial '${target.$2}'",
      );
      expect(result.exitCode, isNonZero);
      expect(result.stderr as String, contains('disposable emulator'));
    }
    final ProcessResult allowed = runHelperFixture(
      'qa-target-allowed',
      "Assert-QAJourneyTarget -Profile 'qa' -Serial 'emulator-5554'",
    );
    expect(allowed.exitCode, 0, reason: allowed.stderr as String);
  });

  test('runtime sequence config explicitly orders all eleven QA journeys', () {
    final File config = File('${temporaryDirectory.path}/sequence.yaml');
    final ProcessResult result = runHelperFixture('runtime-order', '''
New-MaestroSequenceConfig -Flows @(Get-SelectedFlows -SelectedSuite 'qa-journeys') -OutputPath ${psLiteral(config.path)} | ConvertTo-Json -Depth 4 -Compress
''');
    expect(result.exitCode, 0, reason: result.stderr as String);
    final Map<String, dynamic> receipt = output(result);
    final Map<String, dynamic> document =
        jsonDecode(config.readAsStringSync().replaceFirst('\ufeff', ''))
            as Map<String, dynamic>;
    final Map<String, dynamic> order =
        document['executionOrder'] as Map<String, dynamic>;
    expect(order['continueOnFailure'], isFalse);
    final List<dynamic> names = order['flowsOrder'] as List<dynamic>;
    expect(names, hasLength(11));
    expect(names.toSet(), hasLength(11));
    expect(names.sublist(9), <String>[
      'priority8-learned-lifecycle',
      'priority8-learned-lifecycle-readback',
    ]);
    expect(receipt['flowsOrder'], names);
    expect(receipt['sha256'], matches(RegExp(r'^[A-Fa-f0-9]{64}$')));
    // Check wiring as well as generation: preserving argument order alone is
    // insufficient, and the receipt must retain the actual runtime config.
    final String runner = File(runnerPath).readAsStringSync();
    expect(runner, contains(r"@('--config', $sequenceConfiguration.path)"));
    expect(runner, contains(r'executionOrder = $sequenceConfiguration'));
  });

  test('runtime sequence rejects ambiguous duplicate flow filenames', () {
    final File config = File('${temporaryDirectory.path}/ambiguous.yaml');
    final ProcessResult result = runHelperFixture('ambiguous-order', '''
New-MaestroSequenceConfig -Flows @('flows/09-settings.yaml', 'qa/09-settings.yaml') -OutputPath ${psLiteral(config.path)}
''');
    expect(result.exitCode, isNonZero);
    expect(result.stderr as String, contains('unique flow filenames'));
    expect(config.existsSync(), isFalse);
  });

  test('accepts a terminal JUnit document with passing testcases', () {
    final ProcessResult result = validate(
      'passing.xml',
      xml: '''
<testsuites tests="2" failures="0" errors="0" skipped="0">
  <testsuite name="ChronoSpark" tests="2" failures="0" errors="0" skipped="0">
    <testcase name="planner" />
    <testcase name="timeline" />
  </testsuite>
</testsuites>
''',
    );

    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(output(result), containsPair('Status', 'passed'));
    expect(output(result), containsPair('TerminalParsed', isTrue));
    expect(output(result), containsPair('TestCases', 2));
  });

  test('rejects failures, errors, and skips even with a zero exit context', () {
    final Map<String, String> fixtures = <String, String>{
      'failure.xml': '''
<testsuite tests="1" failures="1" errors="0" skipped="0">
  <testcase name="planner"><failure message="failed" /></testcase>
</testsuite>
''',
      'error.xml': '''
<testsuite tests="1" failures="0" errors="1" skipped="0">
  <testcase name="planner"><error message="errored" /></testcase>
</testsuite>
''',
      'skipped.xml': '''
<testsuite tests="1" failures="0" errors="0" skipped="1">
  <testcase name="planner"><skipped /></testcase>
</testsuite>
''',
    };

    for (final MapEntry<String, String> fixture in fixtures.entries) {
      final ProcessResult result = validate(fixture.key, xml: fixture.value);
      expect(result.exitCode, isNonZero, reason: fixture.key);
      expect(output(result), containsPair('Status', 'failed'));
      expect(
        output(result),
        containsPair('FailureReason', 'non-passing-testcases'),
      );
    }

    final ProcessResult multipleSuites = validate(
      'multiple-failures.xml',
      xml: '''
<testsuites tests="2" failures="2" errors="0" skipped="0">
  <testsuite tests="1" failures="1"><testcase name="one"><failure /></testcase></testsuite>
  <testsuite tests="1" failures="1"><testcase name="two"><failure /></testcase></testsuite>
</testsuites>
''',
    );
    expect(multipleSuites.exitCode, isNonZero);
    expect(output(multipleSuites), containsPair('Failures', 2));
  });

  test('rejects zero-testcase, malformed, and missing JUnit evidence', () {
    final ProcessResult zero = validate(
      'zero.xml',
      xml: '<testsuite tests="0" failures="0" errors="0" skipped="0" />',
    );
    final ProcessResult malformed = validate(
      'malformed.xml',
      xml: '<testsuite><testcase></testsuite>',
    );
    final ProcessResult invalidCount = validate(
      'invalid-count.xml',
      xml: '<testsuite tests="unknown"><testcase name="planner" /></testsuite>',
    );
    final ProcessResult contradictoryCount = validate(
      'contradictory-count.xml',
      xml: '<testsuite tests="0"><testcase name="unexpected" /></testsuite>',
    );
    final ProcessResult missing = validate('missing.xml');

    expect(zero.exitCode, isNonZero);
    expect(output(zero), containsPair('FailureReason', 'zero-testcases'));
    expect(malformed.exitCode, isNonZero);
    expect(
      output(malformed),
      containsPair('FailureReason', 'invalid-junit-xml'),
    );
    expect(invalidCount.exitCode, isNonZero);
    expect(
      output(invalidCount),
      containsPair('FailureReason', 'invalid-junit-count'),
    );
    expect(contradictoryCount.exitCode, isNonZero);
    expect(
      output(contradictoryCount),
      containsPair('FailureReason', 'junit-test-count-mismatch'),
    );
    expect(missing.exitCode, isNonZero);
    expect(output(missing), containsPair('FailureReason', 'missing-junit'));
  });
}
