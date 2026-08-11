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
    test('permission denial fixture is explicit', () {
      fail(
        'Use the isolated non-production Patrol runner; this target must not '
        'use production permission state or an optional skip.',
      );
    });
    return;
  }

  patrolTest('denied notification permission exposes the recovery state', ($) async {
    app.main();
    await _authenticateIfRequired($);
    await _openNavTarget($, 'nav-settings');
    await _waitFor($, find.bySemanticsIdentifier('screen-settings'));
    await _waitFor($, find.bySemanticsIdentifier('notification-request-permission'));

    await $.tester.tap(find.bySemanticsIdentifier('notification-request-permission'));
    await _waitFor($, find.text('Allow Notifications'));
    await $.tester.tap(find.text('Allow Notifications'));
    expect(
      await $.native.isPermissionDialogVisible(
        timeout: const Duration(seconds: 5),
      ),
      isTrue,
    );
    await $.native.denyPermission();
    await _waitFor($, find.text('Permission Denied'));
    await binding.takeScreenshot('device-notification-permission-denied');
  });
}

Future<void> _authenticateIfRequired(PatrolIntegrationTester $) async {
  final Finder auth = find.bySemanticsIdentifier('auth-test-access');
  final Finder nav = find.bySemanticsIdentifier('nav-open-map');
  final Stopwatch clock = Stopwatch()..start();
  while (clock.elapsed < const Duration(seconds: 12)) {
    if (nav.evaluate().isNotEmpty) return;
    if (auth.evaluate().isNotEmpty) {
      await $.tester.tap(auth);
      await _waitFor($, nav);
      return;
    }
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for the real app root or authentication gate.');
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
    if (finder.evaluate().isNotEmpty) return;
    await $.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for required control: $finder');
}
