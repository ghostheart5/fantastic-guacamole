import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every production build entry point freezes launch-sensitive flags', () {
    final String guardedBuild = File(
      'scripts/build_android_aab_prod_guarded.ps1',
    ).readAsStringSync();
    final String releaseWorkflow = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();

    const List<String> disabledFlags = <String>[
      'CHRONOSPARK_VERBOSE_LOGS',
      'CHRONOSPARK_ENABLE_MOCK_LOGIN',
      'CHRONOSPARK_ENABLE_MOCK_MODE',
      'CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS',
      'CHRONOSPARK_PAYWALL_DISABLED',
      'CHRONOSPARK_ENABLE_RUNTIME_FEATURE_FLAGS',
      'CHRONOSPARK_ENABLE_CLOUD_SYNC',
      'CHRONOSPARK_ENABLE_ANALYTICS',
      'CHRONOSPARK_ENABLE_CRASH_REPORTING',
    ];

    expect(guardedBuild, contains("CHRONOSPARK_APP_FLAVOR = 'prod'"));
    expect(
      guardedBuild,
      contains("CHRONOSPARK_ENFORCE_PROD_READINESS = 'true'"),
    );
    expect(
      releaseWorkflow,
      contains('--dart-define=CHRONOSPARK_APP_FLAVOR=prod'),
    );
    expect(
      releaseWorkflow,
      contains('--dart-define=CHRONOSPARK_ENFORCE_PROD_READINESS=true'),
    );

    for (final String flag in disabledFlags) {
      expect(guardedBuild, contains("$flag = 'false'"), reason: flag);
      expect(
        releaseWorkflow,
        contains('--dart-define=$flag=false'),
        reason: flag,
      );
    }
  });

  test('local production builder preserves the frozen source snapshot', () {
    final String guardedBuild = File(
      'scripts/build_android_aab_prod_guarded.ps1',
    ).readAsStringSync();

    expect(
      guardedBuild,
      contains('Production AAB build requires a clean source snapshot.'),
    );
    expect(guardedBuild, contains(r'$sourceCommit = (& git rev-parse HEAD)'));
    expect(guardedBuild, contains(r'$postBuildCommit -ne $sourceCommit'));
    expect(
      guardedBuild,
      contains('Source changed while building the production AAB.'),
    );
    expect(guardedBuild, isNot(contains('Updated pubspec version')));
    expect(
      guardedBuild,
      isNot(contains(r'Set-Content -Path $pubspecPath')),
    );
    expect(
      guardedBuild,
      isNot(contains(r'Set-Content -Path $androidGradlePropsPath')),
    );
    expect(
      guardedBuild,
      contains('does not match committed version'),
    );
    expect(
      guardedBuild,
      contains('Signing source files must remain outside the repository.'),
    );
    expect(
      guardedBuild,
      contains('External key.properties must reference app/upload-keystore.jks.'),
    );
    expect(
      guardedBuild,
      contains(r'Copy-Item -LiteralPath $resolvedSigningPropertiesPath'),
    );
    expect(
      guardedBuild,
      contains(r'Copy-Item -LiteralPath $resolvedSigningKeystorePath'),
    );
    expect(
      guardedBuild,
      contains(r'Remove-Item -LiteralPath $temporarySigningPropertiesPath'),
    );
    expect(
      guardedBuild,
      contains(r'Remove-Item -LiteralPath $temporarySigningKeystorePath'),
    );
    expect(guardedBuild, isNot(contains('OneDrive - Heartedghost')));
  });
}
