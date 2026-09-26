import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/public_release_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compiled public intent cannot enable unapproved capabilities', () {
    expect(Env.externalAiEnabled, isFalse);
    expect(Env.creditSpendingEnabled, isFalse);
    expect(Env.paidCreditPlansEnabled, isFalse);
    expect(Env.enableCloudSync, isFalse);
    expect(Env.enableCloudRestore, isFalse);
    final issues = Env.productionReadinessIssues(
      force: true,
      targetPlatform: TargetPlatform.android,
    );
    if (PublicReleaseProfile.requested) {
      expect(
        issues,
        contains('Independent privacy/legal review is missing in source.'),
      );
      expect(
        issues,
        contains(
          'Independent mental-health safety review is missing in source.',
        ),
      );
    }
  });
}
