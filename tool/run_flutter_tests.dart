import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int _usageExitCode = 64;
const int _defaultTimeoutSeconds = 900;

/// Options for one bounded `flutter test` invocation.
final class FlutterTestRunnerOptions {
  const FlutterTestRunnerOptions({
    required this.reportPath,
    required this.manifestPath,
    required this.testArguments,
    this.timeout = const Duration(seconds: _defaultTimeoutSeconds),
    this.allowedSkips = 0,
  });

  final String reportPath;
  final String manifestPath;
  final List<String> testArguments;
  final Duration timeout;
  final int allowedSkips;
}

/// Aggregated non-hidden test results from Flutter's line-delimited JSON report.
final class FlutterJsonReportSummary {
  const FlutterJsonReportSummary({
    required this.total,
    required this.passed,
    required this.failed,
    required this.errors,
    required this.skipped,
    required this.terminalCompleted,
    required this.terminalSuccess,
    required this.parseErrors,
  });

  final int total;
  final int passed;
  final int failed;
  final int errors;
  final int skipped;
  final bool terminalCompleted;
  final bool? terminalSuccess;
  final List<String> parseErrors;
}

/// Final gate inputs, separated from process execution for focused testing.
final class FlutterTestRunResult {
  const FlutterTestRunResult({
    required this.report,
    required this.exitCode,
    required this.timedOut,
    required this.launchFailed,
    required this.allowedSkips,
  });

  final FlutterJsonReportSummary report;
  final int? exitCode;
  final bool timedOut;
  final bool launchFailed;
  final int allowedSkips;

  bool get succeeded {
    return !timedOut &&
        !launchFailed &&
        exitCode == 0 &&
        report.terminalCompleted &&
        report.terminalSuccess == true &&
        report.total > 0 &&
        report.failed == 0 &&
        report.errors == 0 &&
        report.skipped <= allowedSkips &&
        report.parseErrors.isEmpty;
  }
}

Future<void> main(List<String> arguments) async {
  try {
    final FlutterTestRunnerOptions options = parseRunnerOptions(arguments);
    exitCode = await runFlutterTests(options);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = _usageExitCode;
  }
}

FlutterTestRunnerOptions parseRunnerOptions(List<String> arguments) {
  final int separator = arguments.indexOf('--');
  if (separator < 0) {
    throw const FormatException(
      'Runner options and flutter test arguments must be separated by --.',
    );
  }

  String? reportPath;
  String? manifestPath;
  int timeoutSeconds = _defaultTimeoutSeconds;
  int allowedSkips = 0;
  final List<String> runnerArguments = arguments.sublist(0, separator);

  for (int index = 0; index < runnerArguments.length; index += 1) {
    final String argument = runnerArguments[index];
    String nextValue(String option) {
      index += 1;
      if (index >= runnerArguments.length) {
        throw FormatException('$option requires a value.');
      }
      return runnerArguments[index];
    }

    switch (argument) {
      case '--report':
        reportPath = nextValue(argument);
      case '--manifest':
        manifestPath = nextValue(argument);
      case '--timeout-seconds':
        timeoutSeconds = _positiveInteger(nextValue(argument), argument);
      case '--allowed-skips':
        allowedSkips = _nonNegativeInteger(nextValue(argument), argument);
      default:
        throw FormatException('Unknown runner option: $argument');
    }
  }

  if (reportPath == null || reportPath.isEmpty) {
    throw const FormatException('--report is required.');
  }
  if (manifestPath == null || manifestPath.isEmpty) {
    throw const FormatException('--manifest is required.');
  }
  if (_normalizedAbsolutePath(reportPath) ==
      _normalizedAbsolutePath(manifestPath)) {
    throw const FormatException('--report and --manifest must differ.');
  }

  final List<String> testArguments = arguments.sublist(separator + 1);
  if (testArguments.any(_isFileReporterArgument)) {
    throw const FormatException(
      'Caller-provided --file-reporter is not allowed; the runner owns it.',
    );
  }

  return FlutterTestRunnerOptions(
    reportPath: reportPath,
    manifestPath: manifestPath,
    testArguments: List<String>.unmodifiable(testArguments),
    timeout: Duration(seconds: timeoutSeconds),
    allowedSkips: allowedSkips,
  );
}

String _normalizedAbsolutePath(String path) {
  final String normalized = File(
    path,
  ).absolute.uri.normalizePath().toFilePath();
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

int _positiveInteger(String value, String option) {
  final int? parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$option must be a positive integer.');
  }
  return parsed;
}

int _nonNegativeInteger(String value, String option) {
  final int? parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw FormatException('$option must be a non-negative integer.');
  }
  return parsed;
}

bool _isFileReporterArgument(String argument) {
  return argument == '--file-reporter' ||
      argument.startsWith('--file-reporter=');
}

Future<int> runFlutterTests(FlutterTestRunnerOptions options) async {
  final DateTime startedAt = DateTime.now().toUtc();
  final Stopwatch stopwatch = Stopwatch()..start();
  final File reportFile = File(options.reportPath).absolute;
  final File manifestFile = File(options.manifestPath).absolute;
  await reportFile.parent.create(recursive: true);
  await manifestFile.parent.create(recursive: true);
  await reportFile.writeAsString('');

  final List<String> flutterArguments = <String>[
    'test',
    ...options.testArguments,
    '--file-reporter',
    'json:${reportFile.path}',
  ];
  final ({String executable, List<String> arguments, bool runInShell})
  invocation = flutterTestProcessInvocation(flutterArguments);

  Process? process;
  int? childExitCode;
  bool timedOut = false;
  bool launchFailed = false;
  try {
    process = await Process.start(
      invocation.executable,
      invocation.arguments,
      mode: ProcessStartMode.normal,
      runInShell: invocation.runInShell,
    );

    final StreamSubscription<String> stdoutSubscription = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdout.write);
    final StreamSubscription<String> stderrSubscription = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderr.write);
    final Future<void> stdoutDone = stdoutSubscription.asFuture<void>();
    final Future<void> stderrDone = stderrSubscription.asFuture<void>();
    final Future<int> exitFuture = process.exitCode;
    final Completer<Object> timeoutCompleter = Completer<Object>();
    final Timer timeoutTimer = Timer(
      options.timeout,
      () => timeoutCompleter.complete(_timeoutMarker),
    );
    final Object exitOrTimeout = await Future.any<Object>(<Future<Object>>[
      exitFuture,
      timeoutCompleter.future,
    ]);
    timeoutTimer.cancel();

    if (identical(exitOrTimeout, _timeoutMarker)) {
      timedOut = true;
      await _terminateProcess(process);
      childExitCode = await exitFuture
          .then<int?>((int value) => value)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    } else {
      childExitCode = exitOrTimeout as int;
    }

    if (timedOut) {
      await Future.wait<void>(<Future<void>>[
        stdoutSubscription.cancel(),
        stderrSubscription.cancel(),
      ]);
    } else {
      await Future.wait<void>(<Future<void>>[stdoutDone, stderrDone]);
    }
  } on ProcessException {
    launchFailed = true;
  } finally {
    stopwatch.stop();
  }

  final FlutterJsonReportSummary report = await parseFlutterJsonReportFile(
    reportFile,
  );
  final FlutterTestRunResult result = FlutterTestRunResult(
    report: report,
    exitCode: childExitCode,
    timedOut: timedOut,
    launchFailed: launchFailed,
    allowedSkips: options.allowedSkips,
  );
  final DateTime finishedAt = DateTime.now().toUtc();
  final Map<String, Object?> manifest = <String, Object?>{
    'schemaVersion': 1,
    'command': <String, Object>{
      'executable': 'flutter',
      'arguments': sanitizeCommandArguments(flutterArguments),
      'launcher': invocation.executable,
      'isolatedProcessGroup': invocation.executable == 'setsid',
    },
    'reportPath': reportFile.path,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'durationMilliseconds': stopwatch.elapsedMilliseconds,
    'timeoutSeconds': options.timeout.inSeconds,
    'timedOut': timedOut,
    'launchFailed': launchFailed,
    'exitCode': childExitCode,
    'totals': <String, int>{
      'total': report.total,
      'passed': report.passed,
      'failed': report.failed,
      'error': report.errors,
      'skipped': report.skipped,
    },
    'allowedSkips': options.allowedSkips,
    'completedTests': report.total,
    'terminalCompletion': report.terminalCompleted,
    'terminalSuccess': report.terminalSuccess,
    'reportParseErrors': report.parseErrors,
    'finalSuccess': result.succeeded,
  };
  await manifestFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );

  if (!result.succeeded) {
    stderr.writeln(
      'Flutter test evidence gate failed. See ${manifestFile.path}',
    );
    return 1;
  }
  stdout.writeln('Flutter test evidence gate passed. See ${manifestFile.path}');
  return 0;
}

({String executable, List<String> arguments, bool runInShell})
flutterTestProcessInvocation(
  List<String> flutterArguments, {
  bool? isLinux,
  bool? isWindows,
}) {
  final bool linux = isLinux ?? Platform.isLinux;
  final bool windows = isWindows ?? Platform.isWindows;
  if (linux) {
    return (
      executable: 'setsid',
      arguments: <String>['flutter', ...flutterArguments],
      runInShell: false,
    );
  }
  return (
    executable: 'flutter',
    arguments: List<String>.of(flutterArguments),
    runInShell: windows,
  );
}

({String executable, List<String> arguments})? processTreeKillInvocation(
  int processId, {
  bool? isLinux,
  bool? isWindows,
}) {
  final bool linux = isLinux ?? Platform.isLinux;
  final bool windows = isWindows ?? Platform.isWindows;
  if (windows) {
    return (
      executable: 'taskkill',
      arguments: <String>['/PID', '$processId', '/T', '/F'],
    );
  }
  if (linux) {
    return (
      executable: 'kill',
      arguments: <String>['-KILL', '--', '-$processId'],
    );
  }
  return null;
}

Future<void> _terminateProcess(Process process) async {
  final ({String executable, List<String> arguments})? invocation =
      processTreeKillInvocation(process.pid);
  if (invocation == null) {
    process.kill(ProcessSignal.sigkill);
    return;
  }

  Process? killer;
  try {
    killer = await Process.start(
      invocation.executable,
      invocation.arguments,
      mode: ProcessStartMode.normal,
      runInShell: false,
    );
    final int exitCode = await killer.exitCode.timeout(
      const Duration(seconds: 5),
    );
    if (exitCode != 0) {
      process.kill(ProcessSignal.sigkill);
    }
  } on Object {
    killer?.kill(ProcessSignal.sigkill);
    process.kill(ProcessSignal.sigkill);
  }
}

Future<FlutterJsonReportSummary> parseFlutterJsonReportFile(File file) async {
  if (!await file.exists()) {
    return const FlutterJsonReportSummary(
      total: 0,
      passed: 0,
      failed: 0,
      errors: 0,
      skipped: 0,
      terminalCompleted: false,
      terminalSuccess: null,
      parseErrors: <String>['JSON report file was not created.'],
    );
  }
  return parseFlutterJsonReportLines(
    file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
  );
}

Future<FlutterJsonReportSummary> parseFlutterJsonReportLines(
  Stream<String> lines,
) async {
  int total = 0;
  int passed = 0;
  int failed = 0;
  int errors = 0;
  int skipped = 0;
  bool terminalCompleted = false;
  bool? terminalSuccess;
  int lineNumber = 0;
  final Set<Object> completedTestIds = <Object>{};
  final List<String> parseErrors = <String>[];

  await for (final String line in lines) {
    lineNumber += 1;
    if (line.trim().isEmpty) {
      continue;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      parseErrors.add('Line $lineNumber is not valid JSON.');
      continue;
    }
    if (decoded is! Map<String, Object?>) {
      parseErrors.add('Line $lineNumber is not a JSON object.');
      continue;
    }

    final Object? type = decoded['type'];
    if (type == 'done') {
      if (terminalCompleted) {
        parseErrors.add('Line $lineNumber contains a duplicate done event.');
      }
      terminalCompleted = true;
      final Object? success = decoded['success'];
      if (success is bool?) {
        terminalSuccess = success;
      } else {
        parseErrors.add('Line $lineNumber has an invalid done success value.');
      }
      continue;
    }
    if (type != 'testDone' || decoded['hidden'] == true) {
      continue;
    }

    final Object? testId = decoded['testID'];
    if (testId == null) {
      parseErrors.add('Line $lineNumber has no testID.');
      continue;
    }
    if (!completedTestIds.add(testId)) {
      parseErrors.add('Line $lineNumber repeats completed test $testId.');
      continue;
    }

    total += 1;
    if (decoded['skipped'] == true) {
      skipped += 1;
      continue;
    }
    switch (decoded['result']) {
      case 'success':
        passed += 1;
      case 'failure':
        failed += 1;
      case 'error':
        errors += 1;
      default:
        errors += 1;
        parseErrors.add('Line $lineNumber has an unknown test result.');
    }
  }

  return FlutterJsonReportSummary(
    total: total,
    passed: passed,
    failed: failed,
    errors: errors,
    skipped: skipped,
    terminalCompleted: terminalCompleted,
    terminalSuccess: terminalSuccess,
    parseErrors: List<String>.unmodifiable(parseErrors),
  );
}

List<String> sanitizeCommandArguments(List<String> arguments) {
  final RegExp sensitiveName = RegExp(
    r'(api[-_]?key|token|secret|pass(word|wd)?|credential|authorization|cookie|dsn)',
    caseSensitive: false,
  );
  final List<String> sanitized = <String>[];
  bool redactNext = false;

  for (final String argument in arguments) {
    if (redactNext) {
      sanitized.add('<redacted>');
      redactNext = false;
      continue;
    }

    if (argument == '--dart-define' || argument == '-D') {
      sanitized.add(argument);
      redactNext = true;
      continue;
    }
    if (argument.startsWith('--dart-define=') ||
        (argument.startsWith('-D') && argument.contains('='))) {
      final int valueSeparator = argument.lastIndexOf('=');
      sanitized.add('${argument.substring(0, valueSeparator + 1)}<redacted>');
      continue;
    }

    final int lastEquals = argument.lastIndexOf('=');
    if (lastEquals >= 0 &&
        sensitiveName.hasMatch(argument.substring(0, lastEquals))) {
      sanitized.add('${argument.substring(0, lastEquals + 1)}<redacted>');
      continue;
    }
    if (lastEquals < 0 && sensitiveName.hasMatch(argument)) {
      sanitized.add(argument);
      redactNext = true;
      continue;
    }

    sanitized.add(
      argument.replaceAllMapped(
        RegExp(r'(?<=://)[^/@\s]+:[^/@\s]+@'),
        (Match _) => '<redacted>@',
      ),
    );
  }
  return List<String>.unmodifiable(sanitized);
}

const Object _timeoutMarker = Object();

const String _usage = '''
Usage:
  dart run tool/run_flutter_tests.dart \\
    --report <flutter-json-path> \\
    --manifest <manifest-json-path> \\
    [--timeout-seconds <positive-int>] \\
    [--allowed-skips <non-negative-int>] \\
    -- [flutter test arguments]
''';
