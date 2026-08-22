import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final Directory root = Directory.current;

  String read(String path) =>
      File.fromUri(root.uri.resolve(path)).readAsStringSync();

  test('host CI isolates each app-root integration file under Xvfb', () {
    final String workflow = read('.github/workflows/ci.yml');
    final String extended = read('.github/workflows/dart.yml');
    final String linuxRunner = read('scripts/run_linux_integration_tests.sh');
    const String integrationCommand =
        'bash ./scripts/run_linux_integration_tests.sh';
    for (final String hostWorkflow in <String>[workflow, extended]) {
      expect(hostWorkflow, contains('libgtk-3-dev'));
      expect(hostWorkflow, contains('libgstreamer1.0-dev'));
      expect(hostWorkflow, contains('libgstreamer-plugins-base1.0-dev'));
      expect(hostWorkflow, contains('libsecret-1-dev'));
      expect(hostWorkflow, contains('liblzma-dev'));
      expect(hostWorkflow, contains(integrationCommand));
      expect(
        hostWorkflow,
        isNot(contains('flutter test integration_test -d linux')),
      );
    }
    expect(linuxRunner, contains('integration_test/*_test.dart'));
    expect(
      linuxRunner,
      contains(r'xvfb-run -a flutter test "$test_file" --no-pub -d linux'),
    );
    expect(linuxRunner, contains(r'failures=$((failures + 1))'));
    expect(workflow, contains('scripts/edge_function_gate.ps1 -RunTests'));
    expect(workflow, contains('scripts/secret_content_guard.ps1'));
    expect(workflow, contains('scripts/dependency_audit.ps1'));
    expect(workflow, contains('tool/validate_github_workflows.dart'));
    expect(workflow, contains('supabase@2.115.0 test db'));
    expect(workflow, contains('artifacts/ci-evidence/exact-commit.json'));
    expect(
      workflow,
      matches(RegExp(r'uses:\s+actions/upload-artifact@[0-9a-f]{40}\s+# v6')),
    );
  });

  test('GitHub-hosted workflows pin Node 24 artifact actions', () {
    final String workflows = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.yml'))
        .map((File file) => file.readAsStringSync())
        .join('\n');
    expect(
      workflows,
      isNot(
        contains('actions/checkout@11d5960a326750d5838078e36cf38b85af677262'),
      ),
    );
    expect(
      workflows,
      isNot(
        contains(
          'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02',
        ),
      ),
    );
    expect(
      workflows,
      isNot(
        contains(
          'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093',
        ),
      ),
    );
    expect(
      workflows,
      contains(
        'actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5',
      ),
    );
    expect(
      workflows,
      contains(
        'actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f # v6',
      ),
    );
    expect(
      workflows,
      contains(
        'actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131 # v7',
      ),
    );
  });

  test('GitHub workflows pin external actions and hosted runner versions', () {
    final List<File> workflowFiles = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where(
          (File file) =>
              file.path.endsWith('.yml') || file.path.endsWith('.yaml'),
        )
        .toList();
    final String workflows = workflowFiles
        .map((File file) => file.readAsStringSync())
        .join('\n');

    expect(workflows, isNot(contains('ubuntu-latest')));
    expect(workflows, isNot(contains('jekyll/builder:latest')));

    for (final File file in workflowFiles) {
      for (final String line in file.readAsLinesSync()) {
        final String trimmed = line.trim();
        if (!trimmed.startsWith('uses:') || trimmed.contains('uses: ./')) {
          continue;
        }
        final Match? action = RegExp(
          r'^uses:\s+[^@\s]+@([^\s#]+)',
        ).firstMatch(trimmed);
        expect(action, isNotNull, reason: '${file.path}: $trimmed');
        expect(
          action!.group(1),
          matches(RegExp(r'^[0-9a-f]{40}$')),
          reason: '${file.path}: $trimmed',
        );
      }
    }

    final int checkoutCount = RegExp(
      r'uses:\s+actions/checkout@',
    ).allMatches(workflows).length;
    final int readOnlyCheckoutCount = RegExp(
      r'persist-credentials:\s+false',
    ).allMatches(workflows).length;
    expect(readOnlyCheckoutCount, checkoutCount);

    final String ci = read('.github/workflows/ci.yml');
    expect(ci, contains('runs-on: ubuntu-24.04'));
    expect(ci, contains("flutter-version: '3.47.1'"));
    expect(ci, isNot(contains('paths-ignore:')));
  });

  test('application release workflows use the reusable quality gate', () {
    final String android = read('.github/workflows/android-release.yml');
    final String linux = read('.github/workflows/linux-release.yml');
    for (final String workflow in <String>[android, linux]) {
      expect(workflow, contains('uses: ./.github/workflows/ci.yml'));
      expect(workflow, contains('needs: quality-gate'));
    }
    expect(android, contains('::error::Required production secret is missing'));
    expect(android, contains('CHRONOSPARK_ENFORCE_PROD_READINESS=true'));
    expect(android, contains('workflow_dispatch:'));
    expect(android, contains('environment: production'));
    expect(android, contains(r'chronospark-release-${{ github.run_id }}'));
    expect(android, contains('Remove runner-only sensitive material'));
    expect(
      android,
      isNot(
        contains(
          r'--dart-define=CHRONOSPARK_SUPABASE_URL=${{ secrets.CHRONOSPARK_SUPABASE_URL }}',
        ),
      ),
    );
    expect(
      android,
      contains(
        "if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')",
      ),
    );
  });

  test(
    'backend reconciliation is bounded and does not print response bodies',
    () {
      final String workflow = read(
        '.github/workflows/backend-reconciliation.yml',
      );
      expect(workflow, contains('contents: read'));
      expect(workflow, contains('environment: production'));
      expect(workflow, contains('timeout-minutes: 10'));
      expect(workflow, contains('--output /dev/null'));
      expect(workflow, isNot(contains('--fail-with-body')));
    },
  );

  test('secret guards scan expanded source types without text conversion', () {
    final String repositoryGuard = read('scripts/security_secret_guard.ps1');
    final String contentGuard = read('scripts/secret_content_guard.ps1');
    expect(repositoryGuard, contains(r'\.env(?:\..+)?'));
    expect(repositoryGuard, contains('jks|keystore|p12|pfx|key'));
    expect(repositoryGuard, contains('--others --exclude-standard'));
    expect(contentGuard, contains("'.sql'"));
    expect(contentGuard, contains("'.plist'"));
    expect(contentGuard, contains('--others --exclude-standard'));
    expect(contentGuard, contains('git log --no-textconv'));
    expect(contentGuard, contains("throw 'git history scan failed.'"));
  });

  test('public Pages workflow deploys only the verified static site', () {
    final String pages = read('.github/workflows/main.yml');
    expect(pages, contains('Deploy ChronoSpark Public Site to GitHub Pages'));
    expect(pages, contains("- 'site/**'"));
    expect(pages, contains("- 'web/privacy/**'"));
    expect(pages, contains("- 'web/delete-account/**'"));
    expect(pages, contains('verified web app is not published here yet'));
    expect(pages, contains('needs: build'));
    expect(pages, contains('pages: write'));
    expect(pages, contains('id-token: write'));
    expect(
      pages,
      matches(
        RegExp(r'uses:\s+actions/upload-pages-artifact@[0-9a-f]{40}\s+# v3'),
      ),
    );
    expect(
      pages,
      matches(RegExp(r'uses:\s+actions/deploy-pages@[0-9a-f]{40}\s+# v4')),
    );
    expect(pages, isNot(contains('flutter build')));
    expect(pages, isNot(contains('CHRONOSPARK_APP_FLAVOR=prod')));
    expect(pages, isNot(contains('CHRONOSPARK_ENFORCE_PROD_READINESS=true')));
  });

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
    'advanced CodeQL workflow stays retired while default setup owns scanning',
    () {
      final File advancedWorkflow = File.fromUri(
        root.uri.resolve('.github/workflows/codeql.yml'),
      );
      final String workflows = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.yml') || file.path.endsWith('.yaml'),
          )
          .map((File file) => file.readAsStringSync())
          .join('\n');

      expect(advancedWorkflow.existsSync(), isFalse);
      expect(workflows, isNot(contains('github/codeql-action/')));
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
