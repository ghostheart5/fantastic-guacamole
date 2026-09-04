import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const String expectedCommit = '0123456789abcdef0123456789abcdef01234567';
  final File verifier = File('scripts/verify_database_evidence.ps1').absolute;
  late String source;
  late Directory temporaryDirectory;

  setUpAll(() {
    source = verifier.readAsStringSync();
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chronospark-database-evidence-',
    );
  });

  tearDownAll(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  ProcessResult verify({
    Object? commit = expectedCommit,
    Object? schemaVersion = 1,
    Object? runId = '12345',
    Object? runAttempt = '1',
    String junit =
        '<testsuites tests="1" failures="0" errors="0" skipped="0">'
        '<testsuite name="edge" tests="1" failures="0" errors="0" skipped="0">'
        '<testcase classname="edge" name="works" />'
        '</testsuite></testsuites>',
  }) {
    final File exactCommit =
        File('${temporaryDirectory.path}/exact-commit.json')..writeAsStringSync(
          jsonEncode(<String, Object?>{
            'schemaVersion': schemaVersion,
            'commit': commit,
            'runId': runId,
            'runAttempt': runAttempt,
          }),
        );
    final File junitFile = File('${temporaryDirectory.path}/edge.junit.xml')
      ..writeAsStringSync(junit);

    return Process.runSync(
      Platform.isWindows ? 'powershell.exe' : 'pwsh',
      <String>[
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        verifier.path,
        '-ExactCommitPath',
        exactCommit.path,
        '-EdgeJUnitPath',
        junitFile.path,
        '-ExpectedCommit',
        expectedCommit,
      ],
    );
  }

  test(
    'verifier source binds clean nonempty JUnit to exact workflow source',
    () {
      expect(source, contains(r'$source.schemaVersion -ne 1'));
      expect(source, contains(r'$source.commit -cne'));
      expect(source, contains(r'$source.runId'));
      expect(source, contains(r'$source.runAttempt'));
      expect(source, contains(r'$testCases.Count -le 0'));
      expect(source, contains(r'$failures.Count -gt 0'));
      expect(source, contains(r'$errors.Count -gt 0'));
      expect(source, contains(r'$skipped.Count -gt 0'));
    },
  );

  test('verifier accepts only matching complete evidence', () {
    final ProcessResult passing = verify();
    expect(passing.exitCode, 0, reason: passing.stderr as String);

    final List<ProcessResult> rejected = <ProcessResult>[
      verify(commit: List<String>.filled(40, 'f').join()),
      verify(schemaVersion: 2),
      verify(runId: ''),
      verify(runAttempt: ''),
      verify(junit: '<testsuites />'),
      verify(
        junit:
            '<testsuites><testsuite><testcase name="bad">'
            '<failure message="failed" />'
            '</testcase></testsuite></testsuites>',
      ),
      verify(
        junit:
            '<testsuites><testsuite><testcase name="skipped">'
            '<skipped />'
            '</testcase></testsuite></testsuites>',
      ),
    ];

    for (final ProcessResult result in rejected) {
      expect(
        result.exitCode,
        isNonZero,
        reason: '${result.stdout}\n${result.stderr}',
      );
    }
  });
}
