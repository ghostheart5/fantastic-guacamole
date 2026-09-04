import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String packageName = 'com.ghostheart5.chronospark';
  const String deviceSerial = 'emulator-5554';
  late String diagnose;
  late String strictGate;
  late String umbrellaGate;
  late String strictGatePath;
  late Directory temporaryDirectory;
  late File runtimeLog;
  late File emptyRuntimeLog;
  late File apk;
  late String apkSha256;

  setUpAll(() {
    diagnose = File(
      'scripts/android_diagnose_one_click.ps1',
    ).readAsStringSync();
    final File strictGateFile = File(
      'scripts/strict_android_runtime_gate.ps1',
    ).absolute;
    strictGate = strictGateFile.readAsStringSync();
    umbrellaGate = File('scripts/strict_gate.ps1').readAsStringSync();
    strictGatePath = strictGateFile.path;
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'chronospark-runtime-gate-',
    );
    runtimeLog = File('${temporaryDirectory.path}/runtime.log')
      ..writeAsStringSync('ChronoSpark clean runtime fixture.');
    emptyRuntimeLog = File('${temporaryDirectory.path}/empty-runtime.log')
      ..writeAsStringSync('');
    apk = File('${temporaryDirectory.path}/app-debug.apk')
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);
    apkSha256 = sha256.convert(apk.readAsBytesSync()).toString().toUpperCase();
  });

  tearDownAll(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test(
    'diagnose requires one explicit device and bounds native operations',
    () {
      expect(diagnose, contains(r'[string]$DeviceSerial'));
      expect(diagnose, contains(r'$matchingDevices.Count -ne 1'));
      expect(diagnose, contains("'device-serial-required'"));
      expect(diagnose, contains("'selected-device-not-connected'"));
      expect(diagnose, isNot(contains(r'$connectedDevices')));
      expect(diagnose, isNot(contains('5555..5565')));
      expect(diagnose, contains('function Invoke-BoundedCommand'));
      expect(
        diagnose,
        contains(r'$process.WaitForExit($TimeoutSeconds * 1000)'),
      );
      expect(diagnose, contains(r'$stdoutTask.Wait(5000)'));
      expect(diagnose, contains('function Stop-NativeProcessTree'));
      expect(diagnose, contains(r'-TimeoutSeconds $BuildTimeoutSeconds'));
      expect(diagnose, contains(r'-TimeoutSeconds $AdbTimeoutSeconds'));
      expect(diagnose, contains(r"'launch-readiness-not-established'"));
      expect(diagnose, contains(r'$readiness.PidObserved'));
      expect(diagnose, contains(r'$readiness.Focused'));
      expect(diagnose, contains(r'$readiness.ProbeCommandsSucceeded'));
      expect(diagnose, contains(r'$evidence.logcatCollected'));
      expect(diagnose, contains(r'$evidence.logcatByteCount'));
      expect(diagnose, contains("'logcat-evidence-empty'"));
    },
  );

  test('strict gate passes exact selection and validates launch evidence', () {
    expect(strictGate, contains(r'[string]$DeviceSerial'));
    expect(strictGate, contains(r"'-DeviceSerial'"));
    expect(strictGate, contains(r'$DeviceSerial'));
    expect(strictGate, contains(r"'-LaunchEvidencePath'"));
    expect(strictGate, contains('function Test-LaunchEvidence'));
    expect(strictGate, contains(r"$evidence.status -ne 'passed'"));
    expect(strictGate, contains(r'$evidence.deviceSerial -cne'));
    expect(strictGate, contains("'apk-evidence-hash-mismatch'"));
    expect(strictGate, contains(r'$evidence.launch.pidObserved -ne $true'));
    expect(strictGate, contains(r'$evidence.launch.focused -ne $true'));
    expect(
      strictGate,
      contains(r'$evidence.launch.probeCommandsSucceeded -ne $true'),
    );
    expect(strictGate, contains("'logcatDump'"));
    expect(strictGate, contains(r'$operation.timedOut -ne $false'));
    expect(strictGate, contains(r'$evidence.logcatCollected -ne $true'));
    expect(strictGate, contains(r'$evidence.logcatByteCount'));
    expect(strictGate, contains("'runtime-log-empty'"));
    expect(strictGate, contains('function Invoke-BoundedDiagnose'));
    expect(strictGate, contains(r'-TimeoutSeconds $DiagnoseTimeoutSeconds'));
    expect(strictGate, isNot(contains('android_logcat_scan_latest.ps1')));
    expect(umbrellaGate, contains(r'[string]$AndroidDeviceSerial'));
    expect(umbrellaGate, contains(r"'-DeviceSerial'"));
    expect(umbrellaGate, contains(r'$AndroidDeviceSerial'));
    expect(umbrellaGate, contains(r'androidRuntimeEvidence ='));
    expect(umbrellaGate, contains(r"'-LaunchEvidencePath'"));
  });

  Map<String, dynamic> passingEvidence() {
    final Map<String, dynamic> operation = <String, dynamic>{
      'status': 'passed',
      'exitCode': 0,
      'timedOut': false,
      'durationSeconds': 0.1,
      'verified': true,
    };
    return <String, dynamic>{
      'schemaVersion': 1,
      'status': 'passed',
      'packageName': packageName,
      'deviceSerial': deviceSerial,
      'deviceVerified': true,
      'runtimeLog': runtimeLog.path,
      'apk': <String, dynamic>{'path': apk.path, 'sha256': apkSha256},
      'operations': <String, dynamic>{
        for (final String name in <String>[
          'adbStart',
          'deviceQuery',
          'build',
          'install',
          'logcatClear',
          'forceStop',
          'monkeyLaunch',
          'logcatDump',
        ])
          name: Map<String, dynamic>.from(operation),
      },
      'launch': <String, dynamic>{
        'commandsSucceeded': true,
        'fallbackAttempted': false,
        'ready': true,
        'pidObserved': true,
        'focused': true,
        'pid': '4242',
        'focus':
            'mCurrentFocus=Window{abc u0 $packageName/com.ghostheart5.chronospark.MainActivity}',
        'stableSamples': 2,
        'probeCommandsSucceeded': true,
      },
      'logcatCollected': true,
      'logcatByteCount': runtimeLog.lengthSync(),
      'fatalMarkerCount': 0,
    };
  }

  ProcessResult validate(Map<String, dynamic> evidence, String name) {
    final File fixture = File('${temporaryDirectory.path}/$name.json')
      ..writeAsStringSync(jsonEncode(evidence));
    return Process.runSync(
      Platform.isWindows ? 'powershell.exe' : 'pwsh',
      <String>[
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        strictGatePath,
        '-PackageName',
        packageName,
        '-DeviceSerial',
        deviceSerial,
        '-ValidateEvidenceOnlyPath',
        fixture.path,
      ],
    );
  }

  Map<String, dynamic> withLaunchChanges(Map<String, dynamic> changes) {
    final Map<String, dynamic> evidence = passingEvidence();
    final Map<String, dynamic> launch =
        evidence['launch']! as Map<String, dynamic>;
    launch.addAll(changes);
    return evidence;
  }

  Map<String, dynamic> withOperationChange(
    String operationName,
    String field,
    Object value,
  ) {
    final Map<String, dynamic> evidence = passingEvidence();
    final Map<String, dynamic> operations =
        evidence['operations']! as Map<String, dynamic>;
    final Map<String, dynamic> operation =
        operations[operationName]! as Map<String, dynamic>;
    operation[field] = value;
    return evidence;
  }

  test('structured launch evidence validation is fail-closed', () {
    final ProcessResult passing = validate(passingEvidence(), 'passing');
    expect(passing.exitCode, 0, reason: '${passing.stdout}\n${passing.stderr}');

    final Map<String, Map<String, dynamic>> rejected =
        <String, Map<String, dynamic>>{
          'failed-status': passingEvidence()..['status'] = 'failed',
          'wrong-device': passingEvidence()..['deviceSerial'] = 'emulator-5556',
          'missing-pid': withLaunchChanges(<String, dynamic>{
            'pid': '',
            'pidObserved': false,
          }),
          'not-focused': withLaunchChanges(<String, dynamic>{'focused': false}),
          'probe-failed': withLaunchChanges(<String, dynamic>{
            'probeCommandsSucceeded': false,
          }),
          'logcat-timeout': withOperationChange('logcatDump', 'timedOut', true),
          'launch-command-failed': withOperationChange(
            'monkeyLaunch',
            'exitCode',
            1,
          ),
          'logcat-not-collected': passingEvidence()
            ..['logcatCollected'] = false,
          'logcat-zero-bytes': passingEvidence()..['logcatByteCount'] = 0,
        };

    final Map<String, dynamic> emptyLog = passingEvidence()
      ..['runtimeLog'] = emptyRuntimeLog.path
      ..['logcatByteCount'] = 1;
    rejected['empty-runtime-log'] = emptyLog;

    final Map<String, dynamic> wrongApkHash = passingEvidence();
    (wrongApkHash['apk']! as Map<String, dynamic>)['sha256'] =
        List<String>.filled(64, '0').join();
    rejected['wrong-apk-hash'] = wrongApkHash;

    for (final MapEntry<String, Map<String, dynamic>> fixture
        in rejected.entries) {
      final ProcessResult result = validate(fixture.value, fixture.key);
      expect(result.exitCode, isNonZero, reason: fixture.key);
    }
  });
}
