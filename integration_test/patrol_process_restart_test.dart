import 'package:fantastic_guacamole/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

const bool _runNativePatrol = bool.fromEnvironment('RUN_NATIVE_PATROL');
const bool _mockMode = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_MODE');
const bool _mockLogin = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_LOGIN');
const String _taskTitle = String.fromEnvironment('E2E_TASK_TITLE');

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!_runNativePatrol || !_mockMode || !_mockLogin || _taskTitle.isEmpty) {
    test('process restart device fixture is explicit', () {
      fail(
        'Process restart requires the isolated mock configuration and an '
        'E2E_TASK_TITLE created by the preceding application journey.',
      );
    });
    return;
  }

  patrolTest('process restart preserves the saved task and settings state', ($) async {
    app.main();
    await _authenticateIfRequired($);

    await _openNavTarget($, 'nav-timeline');
    await _waitFor($, find.bySemanticsIdentifier('screen-timeline'));
    await _waitFor($, find.text(_taskTitle));

    await _openNavTarget($, 'nav-settings');
    await _waitFor($, find.bySemanticsIdentifier('screen-settings'));
    final Switch darkMode = $.tester.widget<Switch>(
      find.byKey(const Key('settings_dark_mode_toggle')),
    );
    expect(darkMode.value, isTrue);
    await binding.takeScreenshot('device-process-restart-state-preserved');
  });
}

Future<void> _authenticateIfRequired(PatrolIntegrationTester $) async {
  final Finder auth = find.bySemanticsIdentifier('auth-test-access');
  final Finder nav = find.bySemanticsIdentifier('nav-open-map');
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < const Duration(seconds: 12)) {
    if (nav.evaluate().isNotEmpty) {
      return;
    }
    if (auth.evaluate().isNotEmpty) {
      await $.tester.tap(auth);
      await _waitFor($, nav);
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for the restored app root or authentication gate.');
}

Future<void> _openNavTarget(PatrolIntegrationTester $, String target) async {
  await $.tester.tap(find.bySemanticsIdentifier('nav-open-map'));
  await _waitFor($, find.bySemanticsIdentifier(target));
  await $.tester.tap(find.bySemanticsIdentifier(target));
}

Future<void> _waitFor(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < timeout) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for required control: $finder');
}
