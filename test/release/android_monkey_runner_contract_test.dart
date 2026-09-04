import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String runner;

  setUpAll(() {
    runner = File('scripts/run_android_monkey_matrix.ps1').readAsStringSync();
  });

  test('waits for stable ChronoSpark focus before stress input', () {
    expect(runner, contains('function Wait-ForPackageFocus'));
    expect(runner, contains("'shell', 'pidof', \$PackageName"));
    expect(runner, contains("'shell', 'dumpsys', 'window', 'displays'"));
    expect(runner, contains('[int]\$RequiredStableSamples = 2'));

    final int launch = runner.indexOf(r'$launchResult = Invoke-Adb');
    final int readiness = runner.indexOf(
      r'$startupReadiness = Wait-ForPackageFocus',
    );
    final int stress = runner.indexOf(r'$monkeyResult = Invoke-Adb');

    expect(launch, greaterThanOrEqualTo(0));
    expect(readiness, greaterThan(launch));
    expect(stress, greaterThan(readiness));
  });

  test('keeps startup readiness in pass and evidence contracts', () {
    expect(runner, contains(r'$passed = $startupReadiness.Ready -and'));
    expect(runner, contains('startupReady = \$startupReadiness.Ready'));
    expect(runner, contains('startupWaitSeconds ='));
    expect(runner, contains('startupLastFocus ='));
    expect(runner, contains('stressMonkeyStarted = \$stressMonkeyStarted'));
    expect(
      runner,
      contains(
        'Stress Monkey was not started because ChronoSpark did not acquire a stable focused window.',
      ),
    );
  });

  test('requires exactly the requested number of injected events', () {
    expect(runner, contains(r"'(?m)^\s*Events injected:\s*(\d+)\s*$'"));
    expect(runner, contains(r'$injectedEventMatches.Count -eq 1 -and'));
    expect(runner, contains(r'[int]::TryParse('));
    expect(runner, contains(r'$injectedEvents -eq $events'));
    expect(runner, contains(r'$eventCountVerified -and'));
    expect(runner, contains(r'requestedEvents = $events'));
    expect(runner, contains(r'injectedEvents = $injectedEvents'));
    expect(runner, contains(r'eventCountVerified = $eventCountVerified'));

    final RegExp eventCount = RegExp(
      r'^\s*Events injected:\s*(\d+)\s*$',
      multiLine: true,
    );
    expect(eventCount.firstMatch('Events injected: 250')?.group(1), '250');
    expect(eventCount.hasMatch('Events injected: 250 extra'), isFalse);
    expect(eventCount.hasMatch('No events injected'), isFalse);
  });

  test('binds every passing matrix to an installed exact APK', () {
    expect(runner, contains('-ApkPath is required'));
    expect(runner, contains('-ExpectedApkSha256 must be the exact'));
    expect(runner, contains(r'$apkHash -ne $ExpectedApkSha256.Trim()'));
    expect(
      runner,
      contains("'install', '--no-streaming', '-r', '-t', \$resolvedApk"),
    );
    expect(runner, contains(r'path = $resolvedApk'));
    expect(runner, contains(r'sha256 = $apkHash'));
    expect(runner, contains(r'installExitCode = $installResult.ExitCode'));
    expect(runner, contains(r'installTimedOut = $installResult.TimedOut'));
  });

  test('bounds adb and each stress variant and records timeout truth', () {
    expect(runner, contains('[int]\$AdbCommandTimeoutSeconds = 30'));
    expect(runner, contains('[int]\$VariantTimeoutSeconds = 300'));
    expect(runner, contains(r'$process.WaitForExit($TimeoutSeconds * 1000)'));
    expect(runner, contains(r'$killer.WaitForExit(5000)'));
    expect(runner, contains(r'$stdoutTask.Wait(5000)'));
    expect(runner, contains(r'$stderrTask.Wait(5000)'));
    expect(runner, isNot(contains(r'GetAwaiter().GetResult()')));
    expect(runner, contains(r'-TimeoutSeconds $VariantTimeoutSeconds'));
    expect(runner, contains(r'-not $monkeyTimedOut -and'));
    expect(runner, contains(r'monkeyTimedOut = $monkeyTimedOut'));
    expect(runner, contains(r'variantTimeoutSeconds = $VariantTimeoutSeconds'));
  });

  test(
    'requires successful logcat collection in pass and evidence contracts',
    () {
      expect(
        runner,
        contains("Invoke-Adb -Arguments @('-s', \$serial, 'logcat', '-c')"),
      );
      expect(runner, isNot(contains("'threadtime', '-T'")));
      expect(
        runner,
        contains(r'$logcatCollected = $logcatResult.ExitCode -eq 0'),
      );
      expect(runner, contains(r'@($logcatResult.Output).Count -gt 0'));
      expect(runner, contains(r'$logcatCollected -and'));
      expect(runner, contains(r'logcatClearExitCode ='));
      expect(runner, contains(r'logcatClearTimedOut ='));
      expect(runner, contains(r'logcatExitCode = $logcatResult.ExitCode'));
      expect(runner, contains(r'logcatTimedOut = $logcatResult.TimedOut'));
      expect(runner, contains(r'logcatCollected = $logcatCollected'));
    },
  );

  test('proves relaunch from a stopped process with stable focus', () {
    final int stress = runner.indexOf(r'$monkeyResult = Invoke-Adb');
    final int relaunchStop = runner.indexOf(
      r'$relaunchStopResult = Invoke-Adb',
      stress,
    );
    final int postStopPid = runner.indexOf(
      r'$postStopPidResult = Invoke-Adb',
      relaunchStop,
    );
    final int relaunchLaunch = runner.indexOf(
      r'$relaunchResult = Invoke-Adb',
      postStopPid,
    );
    final int relaunchReadiness = runner.indexOf(
      r'$relaunchReadiness = Wait-ForPackageFocus',
      relaunchLaunch,
    );

    expect(relaunchStop, greaterThan(stress));
    expect(postStopPid, greaterThan(relaunchStop));
    expect(relaunchLaunch, greaterThan(postStopPid));
    expect(relaunchReadiness, greaterThan(relaunchLaunch));
    expect(
      runner.substring(relaunchStop, postStopPid),
      contains(r"'shell', 'am', 'force-stop', $packageName"),
    );
    expect(runner, contains(r'$relaunchProcessAbsent -and'));
    expect(runner, contains(r'$relaunchReadiness.Ready'));
    expect(runner, contains(r'relaunchProcessAbsent = $relaunchProcessAbsent'));
    expect(runner, contains(r'relaunchReady = $relaunchReadiness.Ready'));
    expect(runner, contains(r'relaunchSucceeded = $relaunchSucceeded'));
  });
}
