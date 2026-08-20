import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final Directory root = Directory.current;

  String read(String path) =>
      File.fromUri(root.uri.resolve(path)).readAsStringSync();

  test(
    'primary CI covers all Edge Functions and app-root integration tests',
    () {
      final String workflow = read('.github/workflows/ci.yml');
      expect(workflow, contains('scripts/edge_function_gate.ps1 -RunTests'));
      expect(
        workflow,
        contains('flutter test integration_test --concurrency=1'),
      );
      expect(workflow, contains('scripts/secret_content_guard.ps1'));
      expect(workflow, contains('scripts/dependency_audit.ps1'));
      expect(workflow, contains('supabase@2.115.0 test db'));
      expect(workflow, contains('artifacts/ci-evidence/exact-commit.json'));
      expect(workflow, contains('actions/upload-artifact@v4'));
    },
  );

  test(
    'production workflows fail closed and use explicit production flavor',
    () {
      final String android = read('.github/workflows/android-release.yml');
      final String web = read('.github/workflows/main.yml');
      final String linux = read('.github/workflows/linux-release.yml');
      for (final String workflow in <String>[android, web, linux]) {
        expect(workflow, contains('uses: ./.github/workflows/ci.yml'));
        expect(workflow, contains('needs: quality-gate'));
      }
      expect(
        android,
        contains('::error::Required production secret is missing'),
      );
      expect(android, contains('CHRONOSPARK_ENFORCE_PROD_READINESS=true'));
      expect(web, contains('CHRONOSPARK_APP_FLAVOR=prod'));
      expect(web, contains('CHRONOSPARK_ENFORCE_PROD_READINESS=true'));
      expect(web, isNot(contains('::warning::Missing repository secrets')));
    },
  );

  test(
    'release source contracts use the current target API and Firebase identity',
    () {
      final String gradle = read('android/app/build.gradle.kts');
      final String guard = read('scripts/release_guard.ps1');
      final String firebase = read('lib/firebase_options.dart');
      expect(gradle, contains('maxOf(flutter.compileSdkVersion, 36)'));
      expect(gradle, contains('maxOf(flutter.targetSdkVersion, 36)'));
      expect(guard, contains('\$requiredTargetApi = 36'));
      expect(guard, contains("'android.permission.ACCESS_COARSE_LOCATION'"));
      expect(guard, contains("'android.permission.ACCESS_FINE_LOCATION'"));
      expect(firebase, contains("iosBundleId: 'com.ghostheart5.chronospark'"));
      expect(firebase, isNot(contains('com.example.chronospark')));
    },
  );

  test(
    'CodeQL no longer mutates repository security settings or hides SARIF failures',
    () {
      final String codeql = read('.github/workflows/codeql.yml');
      expect(codeql, isNot(contains('PATCH')));
      expect(codeql, contains('upload: true'));
      expect(codeql, isNot(contains('continue-on-error: true')));
    },
  );

  test(
    'runtime and golden workflows cannot mutate source or build a candidate',
    () {
      final String maestro = read('.github/workflows/maestro-runtime.yml');
      final String goldens = read('.github/workflows/update-goldens.yml');
      expect(maestro, contains('self-hosted, android, maestro'));
      expect(maestro, isNot(contains('flutter build')));
      expect(goldens, contains('contents: read'));
      expect(goldens, contains('Upload golden update for review'));
      expect(goldens, isNot(contains('git push')));
    },
  );
}
