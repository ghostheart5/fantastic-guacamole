import 'dart:convert';

import '../../tool/run_flutter_tests.dart' as runner;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flutter JSON report evidence gate', () {
    test('rejects a terminal report with zero completed tests', () async {
      final runner.FlutterTestRunResult result = await _result(<String>[
        _event(<String, Object?>{'type': 'done', 'success': true}),
      ]);

      expect(result.report.total, 0);
      expect(result.succeeded, isFalse);
    });

    test('rejects a report without terminal completion', () async {
      final runner.FlutterTestRunResult result = await _result(<String>[
        _testDone(1, 'success'),
      ]);

      expect(result.report.total, 1);
      expect(result.report.terminalCompleted, isFalse);
      expect(result.succeeded, isFalse);
    });

    test('rejects a skip above the default zero budget', () async {
      final runner.FlutterTestRunResult result = await _result(<String>[
        _testDone(1, 'success', skipped: true),
        _event(<String, Object?>{'type': 'done', 'success': true}),
      ]);

      expect(result.report.skipped, 1);
      expect(result.succeeded, isFalse);
    });

    test('accepts a skip within an explicit budget', () async {
      final runner.FlutterTestRunResult result = await _result(<String>[
        _testDone(1, 'success'),
        _testDone(2, 'success', skipped: true),
        _event(<String, Object?>{'type': 'done', 'success': true}),
      ], allowedSkips: 1);

      expect(result.succeeded, isTrue);
    });

    test('rejects failed and error tests', () async {
      final runner.FlutterTestRunResult failed = await _result(<String>[
        _testDone(1, 'failure'),
        _event(<String, Object?>{'type': 'done', 'success': false}),
      ]);
      final runner.FlutterTestRunResult errored = await _result(<String>[
        _testDone(1, 'error'),
        _event(<String, Object?>{'type': 'done', 'success': false}),
      ]);

      expect(failed.report.failed, 1);
      expect(failed.succeeded, isFalse);
      expect(errored.report.errors, 1);
      expect(errored.succeeded, isFalse);
    });

    test(
      'accepts completed passing tests with clean process evidence',
      () async {
        final runner.FlutterTestRunResult result = await _result(<String>[
          _testDone(1, 'success'),
          _testDone(2, 'success'),
          _event(<String, Object?>{'type': 'done', 'success': true}),
        ]);

        expect(result.report.total, 2);
        expect(result.report.passed, 2);
        expect(result.report.parseErrors, isEmpty);
        expect(result.succeeded, isTrue);
      },
    );

    test(
      'rejects malformed report lines, timeouts, and nonzero exits',
      () async {
        final runner.FlutterTestRunResult malformed = await _result(<String>[
          '{not-json',
          _testDone(1, 'success'),
          _event(<String, Object?>{'type': 'done', 'success': true}),
        ]);
        final runner.FlutterTestRunResult timedOut = await _result(<String>[
          _testDone(1, 'success'),
          _event(<String, Object?>{'type': 'done', 'success': true}),
        ], timedOut: true);
        final runner.FlutterTestRunResult nonzero = await _result(<String>[
          _testDone(1, 'success'),
          _event(<String, Object?>{'type': 'done', 'success': true}),
        ], exitCode: 1);

        expect(malformed.report.parseErrors, isNotEmpty);
        expect(malformed.succeeded, isFalse);
        expect(timedOut.succeeded, isFalse);
        expect(nonzero.succeeded, isFalse);
      },
    );
  });

  group('runner options and manifest command safety', () {
    test('Linux starts Flutter in an isolated killable process group', () {
      final invocation = runner.flutterTestProcessInvocation(
        <String>['test', '--no-pub'],
        isLinux: true,
        isWindows: false,
      );
      expect(invocation.executable, 'setsid');
      expect(invocation.arguments, <String>['flutter', 'test', '--no-pub']);
      expect(invocation.runInShell, isFalse);

      final kill = runner.processTreeKillInvocation(
        1234,
        isLinux: true,
        isWindows: false,
      );
      expect(kill?.executable, 'kill');
      expect(kill?.arguments, <String>['-KILL', '--', '-1234']);
    });

    test('Windows uses taskkill for the complete Flutter process tree', () {
      final invocation = runner.flutterTestProcessInvocation(
        <String>['test'],
        isLinux: false,
        isWindows: true,
      );
      expect(invocation.executable, 'flutter');
      expect(invocation.runInShell, isTrue);

      final kill = runner.processTreeKillInvocation(
        5678,
        isLinux: false,
        isWindows: true,
      );
      expect(kill?.executable, 'taskkill');
      expect(kill?.arguments, <String>['/PID', '5678', '/T', '/F']);
    });

    test('requires the runner-owned file reporter', () {
      expect(
        () => runner.parseRunnerOptions(<String>[
          '--report',
          'report.json',
          '--manifest',
          'manifest.json',
          '--',
          '--file-reporter=json:other.json',
        ]),
        throwsFormatException,
      );
    });

    test('redacts common secret-bearing command arguments', () {
      expect(
        runner.sanitizeCommandArguments(<String>[
          '--dart-define=API_KEY=do-not-record',
          '--dart-define=ORDINARY_VALUE=still-do-not-record',
          '--password',
          'do-not-record-either',
          '--server=https://user:password@example.test/path',
        ]),
        <String>[
          '--dart-define=API_KEY=<redacted>',
          '--dart-define=ORDINARY_VALUE=<redacted>',
          '--password',
          '<redacted>',
          '--server=https://<redacted>@example.test/path',
        ],
      );
    });
  });
}

Future<runner.FlutterTestRunResult> _result(
  List<String> lines, {
  int exitCode = 0,
  bool timedOut = false,
  int allowedSkips = 0,
}) async {
  final runner.FlutterJsonReportSummary report = await runner
      .parseFlutterJsonReportLines(Stream<String>.fromIterable(lines));
  return runner.FlutterTestRunResult(
    report: report,
    exitCode: exitCode,
    timedOut: timedOut,
    launchFailed: false,
    allowedSkips: allowedSkips,
  );
}

String _testDone(int id, String result, {bool skipped = false}) {
  return _event(<String, Object?>{
    'type': 'testDone',
    'testID': id,
    'result': result,
    'skipped': skipped,
    'hidden': false,
  });
}

String _event(Map<String, Object?> value) => jsonEncode(value);
