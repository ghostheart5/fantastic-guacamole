import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String readSource(String relativePath) =>
      File(relativePath).readAsStringSync();

  test('telemetry source keeps personal content and account identifiers local', () {
    final String logger = readSource('lib/core/debug/logger.dart');
    final String diagnostics =
        readSource('lib/core/debug/runtime_diagnostics.dart');
    final String providers =
        readSource('lib/state/providers/service_providers.dart');
    final String privacyPolicy = readSource('privacy.html');

    expect(logger, isNot(contains('FirebaseCrashlytics.instance.log(')));
    expect(
      logger,
      contains("StateError('ChronoSpark diagnostic: \$safeCode')"),
    );
    expect(diagnostics, isNot(contains('FirebaseCrashlytics')));
    expect(providers, isNot(contains('setUserIdentifier(')));
    expect(
      privacyPolicy,
      contains('Firebase Analytics and Crashlytics collection are disabled in this release.'),
    );
  });
}
