import 'package:fantastic_guacamole/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

const bool _runNativePatrol = bool.fromEnvironment('RUN_NATIVE_PATROL');
const bool _mockMode = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_MODE');
const bool _mockLogin = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_LOGIN');

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!_runNativePatrol || !_mockMode || !_mockLogin) {
    test('native Patrol is never a skipped pass', () {
      fail(
        'Run through tool/run_patrol_device_tests.ps1 with the required '
        'non-production mock defines and a connected device.',
      );
    });
    return;
  }

  patrolTest('warm launch preserves the real app root after backgrounding', ($) async {
    app.main();
    await _completeOnboardingIfRequired($);
    await $.tester.tap(find.bySemanticsIdentifier('auth-test-access'));
    await _waitFor($, find.bySemanticsIdentifier('nav-open-map'));
    await $.tester.tap(find.bySemanticsIdentifier('nav-open-map'));
    await _waitFor($, find.bySemanticsIdentifier('nav-nexus'));
    await $.tester.tap(find.bySemanticsIdentifier('nav-nexus'));
    await _waitFor($, find.bySemanticsIdentifier('screen-nexus'));
    await binding.takeScreenshot('device-authenticated-nexus');

    await $.native.pressHome();
    await $.native.openApp();
    await _waitFor($, find.bySemanticsIdentifier('nav-open-map'));
    expect(find.bySemanticsIdentifier('nav-open-map'), findsOneWidget);
    await binding.takeScreenshot('device-warm-launch-nexus');
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
  fail('Timed out waiting for $finder');
}
