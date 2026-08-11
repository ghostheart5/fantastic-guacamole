import 'package:fantastic_guacamole/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

const bool _runNativePatrol = bool.fromEnvironment('RUN_NATIVE_PATROL');
const bool _mockMode = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_MODE');
const bool _mockLogin = bool.fromEnvironment('CHRONOSPARK_ENABLE_MOCK_LOGIN');
const bool _expectOffline = bool.fromEnvironment('E2E_EXPECT_OFFLINE');

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (!_runNativePatrol || !_mockMode || !_mockLogin) {
    test('offline fixture is explicit', () {
      fail('Use the isolated non-production Patrol runner; do not skip offline E2E.');
    });
    return;
  }

  patrolTest('real app reports the externally controlled connectivity state', ($) async {
    app.main();
    await _waitFor($, find.bySemanticsIdentifier('nav-open-map'));
    final Finder banner = find.byKey(const Key('offline_banner_live_region'));
    if (_expectOffline) {
      await _waitFor($, banner);
      await binding.takeScreenshot('device-offline-interruption');
    } else {
      await _waitForAbsent($, banner);
      await binding.takeScreenshot('device-offline-recovery');
    }
  });
}

Future<void> _waitFor(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < timeout) {
    if (finder.evaluate().isNotEmpty) return;
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for required control: $finder');
}

Future<void> _waitForAbsent(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < timeout) {
    if (finder.evaluate().isEmpty) return;
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Offline state did not recover before the deadline.');
}
