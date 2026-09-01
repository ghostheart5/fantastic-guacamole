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
    final int stress = runner.indexOf(r'& $script:Adb @monkeyArgs');

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
}
