import 'package:fantastic_guacamole/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

const bool _runNativePatrol = bool.fromEnvironment('RUN_NATIVE_PATROL');
const bool _mockMode = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_MODE');
const bool _mockLogin = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_LOGIN');
const String _runId = String.fromEnvironment('E2E_RUN_ID', defaultValue: 'local');

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!_runNativePatrol || !_mockMode || !_mockLogin) {
    test('application journey requires an isolated device fixture', () {
      fail(
        'Required device journey was not configured. Use mock mode/login, a '
        'dev flavor, cloud sync disabled, and a non-production device.',
      );
    });
    return;
  }

  patrolTest('real root supports Creator, Timeline, Settings, deep link, and logout/login',
      ($) async {
    final String title = 'e2e_device_task_$_runId';
    app.main();
    await _completeOnboardingIfRequired($);
    await _waitFor($, find.bySemanticsIdentifier('auth-test-access'));
    await $.tester.tap(find.bySemanticsIdentifier('auth-test-access'));
    await _waitFor($, find.bySemanticsIdentifier('nav-open-map'));

    await _openNavTarget($, 'nav-creator');
    await _waitFor($, find.bySemanticsIdentifier('creator-title-input'));
    await $.tester.enterText(find.bySemanticsIdentifier('creator-title-input'), title);
    await $.tester.tap(find.bySemanticsIdentifier('creator-submit'));
    await _waitFor($, find.text('Task saved.'));
    await binding.takeScreenshot('device-creator-saved');

    await _openNavTarget($, 'nav-timeline');
    await _waitFor($, find.bySemanticsIdentifier('screen-timeline'));
    await _waitFor($, find.text(title));
    await binding.takeScreenshot('device-timeline-verification');

    await _openNavTarget($, 'nav-settings');
    await _waitFor($, find.bySemanticsIdentifier('screen-settings'));
    final Switch before = $.tester.widget<Switch>(
      find.byKey(const Key('settings_dark_mode_toggle')),
    );
    if (!before.value) {
      await $.tester.tap(find.byKey(const Key('settings_dark_mode_toggle')));
      await _waitForValue($, true);
    }
    await binding.takeScreenshot('device-settings-persisted');

    await $.native.openUrl('https://chronospark.app/app/timeline');
    await _waitFor($, find.bySemanticsIdentifier('screen-timeline'));
    await binding.takeScreenshot('device-deep-link-timeline');

    await _openNavTarget($, 'nav-profile');
    await _waitFor($, find.bySemanticsIdentifier('profile-logout'));
    await $.tester.tap(find.bySemanticsIdentifier('profile-logout'));
    await _waitFor($, find.bySemanticsIdentifier('auth-test-access'));
    await $.tester.tap(find.bySemanticsIdentifier('auth-test-access'));
    await _waitFor($, find.bySemanticsIdentifier('nav-open-map'));
  });
}

Future<void> _completeOnboardingIfRequired(PatrolIntegrationTester $) async {
  final Finder onboarding = find.bySemanticsIdentifier('screen-onboarding');
  final Finder auth = find.bySemanticsIdentifier('auth-test-access');
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < const Duration(seconds: 12)) {
    if (auth.evaluate().isNotEmpty) {
      return;
    }
    if (onboarding.evaluate().isNotEmpty) {
      await $.tester.tap(find.bySemanticsIdentifier('onboarding-skip'));
      await _waitFor($, auth);
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for onboarding or authentication.');
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

Future<void> _waitForValue(PatrolIntegrationTester $, bool expected) async {
  final Stopwatch clock = Stopwatch()..start();
  final Finder toggle = find.byKey(const Key('settings_dark_mode_toggle'));
  while (clock.elapsed < const Duration(seconds: 8)) {
    if (toggle.evaluate().isNotEmpty &&
        $.tester.widget<Switch>(toggle).value == expected) {
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Settings toggle did not persist its new value.');
}
