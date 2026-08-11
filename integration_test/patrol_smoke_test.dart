import 'package:fantastic_guacamole/main.dart' as app;
import 'package:flutter/material.dart';
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
    test('Patrol device configuration is explicit', () {
      fail(
        'Device E2E requires RUN_NATIVE_PATROL=true, '
        'CHRONOSPARK_ENABLE_MOCK_MODE=true, and '
        'CHRONOSPARK_ENABLE_MOCK_LOGIN=true. It must not use a production account.',
      );
    });
    return;
  }

  patrolTest('cold launch completes onboarding and reaches the real authentication gate', ($) async {
    app.main();
    await _completeOnboardingIfRequired($);
    await _waitFor(
      $,
      find.bySemanticsIdentifier('auth-test-access'),
      name: 'mock authentication gate',
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.bySemanticsIdentifier('auth-test-access'), findsOneWidget);
    await binding.takeScreenshot('device-cold-launch-auth-gate');
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
      await _waitFor($, auth, name: 'authentication gate after onboarding');
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for onboarding or the authentication gate.');
}

Future<void> _waitFor(
  PatrolIntegrationTester $,
  Finder finder, {
  required String name,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < timeout) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for required control: $name');
}
