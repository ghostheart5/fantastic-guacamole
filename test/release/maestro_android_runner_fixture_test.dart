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
