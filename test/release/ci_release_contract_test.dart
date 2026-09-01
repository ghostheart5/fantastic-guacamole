import 'dart:io';

import 'package:fantastic_guacamole/config/firebase_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final Directory root = Directory.current;

  String read(String path) =>
      File.fromUri(root.uri.resolve(path)).readAsStringSync();

  YamlMap workflow(String name) =>
      loadYaml(read('.github/workflows/$name')) as YamlMap;

  YamlMap jobs(YamlMap document) => document['jobs'] as YamlMap;

  YamlMap job(YamlMap document, String name) => jobs(document)[name] as YamlMap;

  List<YamlMap> steps(YamlMap job) =>
      (job['steps'] as YamlList).whereType<YamlMap>().toList();

  YamlMap namedStep(YamlMap job, String name) =>
      steps(job).singleWhere((YamlMap step) => step['name'] == name);

  String? environmentName(YamlMap job) {
    final Object? environment = job['environment'];
    if (environment is String) {
      return environment;
    }
    if (environment is YamlMap) {
      return environment['name']?.toString();
    }
    return null;
  }

  bool containsSecret(Object? value) {
    if (value is String) {
      return value.contains(r'${{ secrets.');
    }
    if (value is YamlMap) {
      return value.entries.any(
        (MapEntry<Object?, Object?> entry) =>
            containsSecret(entry.key) || containsSecret(entry.value),
      );
    }
    if (value is YamlList) {
      return value.any(containsSecret);
    }
    return false;
  }

  test('primary CI parses workflow-only changes and runs the policy guard', () {
    final YamlMap ci = workflow('ci.yml');
    final YamlMap triggers = ci['on'] as YamlMap;
    final YamlMap push = triggers['push'] as YamlMap;
    final YamlMap pullRequest = triggers['pull_request'] as YamlMap;
    expect(push.containsKey('paths-ignore'), isFalse);
    expect(pullRequest.containsKey('paths-ignore'), isFalse);
    expect(triggers.containsKey('workflow_call'), isTrue);

    final YamlMap testJob = job(ci, 'test');
    final List<YamlMap> testSteps = steps(testJob);
    expect(
      testSteps.map((YamlMap step) => step['run']),
      contains('dart run tool/validate_github_workflows.dart'),
    );
    expect(
      testSteps.map((YamlMap step) => step['run']),
      contains('bash ./scripts/run_linux_integration_tests.sh'),
    );
    expect(
      testSteps.map((YamlMap step) => step['run']),
      contains('./scripts/version_consistency_guard_contract.ps1'),
    );
    expect(
      testSteps.map((YamlMap step) => step['run']),
      contains('./scripts/edge_function_gate.ps1 -RunTests'),
    );
  });

  test(
    'external actions and mutable toolchain inputs are structurally pinned',
    () {
      final List<File> workflowFiles = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.yml') || file.path.endsWith('.yaml'),
          )
          .toList();
      final List<String> allUses = <String>[];

      for (final File file in workflowFiles) {
        final YamlMap document = loadYaml(file.readAsStringSync()) as YamlMap;
        for (final MapEntry<Object?, Object?> entry in jobs(document).entries) {
          final YamlMap currentJob = entry.value as YamlMap;
          expect(currentJob['runs-on'], anyOf(isNull, isNot('ubuntu-latest')));
          if (currentJob.containsKey('runs-on')) {
            expect(currentJob['timeout-minutes'], isA<int>());
          }

          final Object? jobUses = currentJob['uses'];
          if (jobUses is String) {
            allUses.add(jobUses);
          }
          final Object? stepValues = currentJob['steps'];
          if (stepValues is! YamlList) {
            continue;
          }
          for (final YamlMap step in stepValues.whereType<YamlMap>()) {
            final Object? usesValue = step['uses'];
            if (usesValue is! String) {
              continue;
            }
            allUses.add(usesValue);
            if (usesValue.startsWith('actions/checkout@')) {
              expect((step['with'] as YamlMap)['persist-credentials'], isFalse);
            }
            if (usesValue.startsWith('subosito/flutter-action@')) {
              expect((step['with'] as YamlMap)['flutter-version'], '3.44.6');
            }
          }
        }
      }

      for (final String uses in allUses) {
        if (uses.startsWith('./')) {
          continue;
        }
        if (uses.startsWith('docker://')) {
          expect(
            uses,
            matches(RegExp(r'^docker://[^@\s]+@sha256:[0-9a-f]{64}$')),
          );
        } else {
          expect(uses, matches(RegExp(r'^[^@\s]+@[0-9a-f]{40}$')));
        }
      }

      expect(
        allUses,
        contains('actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09'),
      );
      expect(
        allUses,
        contains(
          'actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f',
        ),
      );
      expect(
        allUses,
        contains(
          'actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131',
        ),
      );
    },
  );

  test('secret-bearing and publishing jobs use protected environments', () {
    final Set<String> protectedJobs = <String>{};
    for (final File file
        in Directory('.github/workflows').listSync().whereType<File>().where(
          (File file) => file.path.endsWith('.yml'),
        )) {
      final String fileName = file.uri.pathSegments.last;
      final YamlMap document = loadYaml(file.readAsStringSync()) as YamlMap;
      final YamlMap workflowPermissions = document['permissions'] as YamlMap;
      for (final MapEntry<Object?, Object?> entry in jobs(document).entries) {
        final String jobName = entry.key.toString();
        final YamlMap currentJob = entry.value as YamlMap;
        final Object? permissions =
            currentJob['permissions'] ?? workflowPermissions;
        final bool writes =
            permissions is YamlMap &&
            permissions.values.any((Object? value) => value == 'write');
        final bool secrets = containsSecret(currentJob);
        if (!writes && !secrets) {
          continue;
        }
        protectedJobs.add('$fileName:$jobName');
        final String expected = fileName == 'main.yml' && jobName == 'deploy'
            ? 'github-pages'
            : 'production';
        expect(environmentName(currentJob), expected);
      }
    }

    expect(
      protectedJobs,
      containsAll(<String>{
        'android-release.yml:build-aab',
        'android-release.yml:publish-release',
        'dart.yml:build',
        'linux-release.yml:build-and-release',
        'maestro-runtime.yml:runtime',
        'main.yml:deploy',
      }),
    );
  });

  test(
    'Android release parses quality, provenance, signing, and publish gates',
    () {
      final YamlMap android = workflow('android-release.yml');
      final YamlMap quality = job(android, 'quality-gate');
      final YamlMap database = job(android, 'database-gate');
      final YamlMap build = job(android, 'build-aab');
      final YamlMap publish = job(android, 'publish-release');
      expect(quality['uses'], './.github/workflows/ci.yml');
      expect(database['uses'], './.github/workflows/supabase-database.yml');
      expect((build['needs'] as YamlList).toSet(), <Object?>{
        'quality-gate',
        'database-gate',
      });
      expect(publish['needs'], 'build-aab');
      expect(environmentName(build), 'production');
      expect(environmentName(publish), 'production');

      final List<YamlMap> buildSteps = steps(build);
      final YamlMap checkout = buildSteps.singleWhere(
        (YamlMap step) =>
            step['uses']?.toString().startsWith('actions/checkout@') == true,
      );
      expect((checkout['with'] as YamlMap)['fetch-depth'], 0);
      expect((checkout['with'] as YamlMap)['persist-credentials'], isFalse);

      final int configIndex = buildSteps.indexOf(
        namedStep(build, 'Validate production configuration'),
      );
      final int backendIndex = buildSteps.indexOf(
        namedStep(
          build,
          'Verify live backend, App Links, RTDN, and Play configuration',
        ),
      );
      final int decodeIndex = buildSteps.indexOf(
        namedStep(build, 'Decode keystore'),
      );
      final int buildIndex = buildSteps.indexOf(
        namedStep(build, 'Build signed AAB'),
      );
      expect(configIndex, lessThan(decodeIndex));
      expect(configIndex, lessThan(buildIndex));
      expect(backendIndex, lessThan(decodeIndex));
      expect(backendIndex, lessThan(buildIndex));
      expect(
        namedStep(build, 'Validate production configuration')['run'],
        contains('scripts/validate_production_config.dart'),
      );
      expect(
        namedStep(build, 'Validate release version and tag')['run'],
        './scripts/version_consistency_guard.ps1 -RequireTag',
      );

      for (final String stepName in <String>[
        'Configure Firebase Android file',
        'Decode keystore',
        'Write key.properties',
      ]) {
        final String run = namedStep(build, stepName)['run'].toString();
        expect(
          run,
          matches(RegExp(r'^\s*umask 077(?:\r?\n|$)')),
          reason: '$stepName must establish a restrictive mask first.',
        );
      }

      for (final YamlMap step in buildSteps) {
        expect(step['run']?.toString() ?? '', isNot(contains(r'${{ secrets.')));
      }
      final YamlMap cleanup = namedStep(
        build,
        'Remove runner-only sensitive material',
      );
      expect(cleanup['if'], 'always()');
      expect(cleanup['run'], contains('android/app/key.jks'));

      final YamlMap upload = namedStep(build, 'Upload AAB artifact');
      final YamlMap uploadWith = upload['with'] as YamlMap;
      expect(
        uploadWith['name'],
        r'chronospark-release-${{ github.run_id }}-${{ github.run_attempt }}',
      );
      expect(uploadWith['if-no-files-found'], 'error');
      final YamlMap download = namedStep(
        publish,
        'Download verified AAB artifact',
      );
      expect((download['with'] as YamlMap)['name'], uploadWith['name']);
      expect(
        namedStep(publish, 'Create GitHub Release')['uses'],
        matches(RegExp(r'^softprops/action-gh-release@[0-9a-f]{40}$')),
      );
    },
  );

  test('production monitoring and upload identity match live contracts', () {
    const String uploadSha1 =
        '8A:24:D7:BA:AC:AB:52:F0:A3:77:7D:D0:47:C9:07:96:2E:82:FA:A5';
    final String androidRelease = read('.github/workflows/android-release.yml');
    final String releaseGovernance = read('docs/GITHUB_RELEASE_GOVERNANCE.md');
    final String reconciliation = read(
      '.github/workflows/backend-reconciliation.yml',
    );

    expect(androidRelease, contains('EXPECTED_UPLOAD_SHA1: "$uploadSha1"'));
    expect(releaseGovernance, contains('`$uploadSha1`'));
    expect(reconciliation, contains('Number.isInteger(body.deferred)'));
    expect(reconciliation, contains('Number.isInteger(body.advanced)'));
    expect(reconciliation, contains('body.scanned - body.advanced'));
    expect(reconciliation, contains('body.completed > body.advanced'));
  });

  test('public Pages workflow parses as static-site-only deployment', () {
    final YamlMap pages = workflow('main.yml');
    final YamlMap triggers = pages['on'] as YamlMap;
    final YamlMap push = triggers['push'] as YamlMap;
    expect((push['branches'] as YamlList), contains('main'));
    expect((push['paths'] as YamlList), contains('site/**'));
    expect((push['paths'] as YamlList), contains('web/delete-account/**'));

    final YamlMap build = job(pages, 'build');
    final YamlMap deploy = job(pages, 'deploy');
    expect(deploy['needs'], 'build');
    expect(environmentName(deploy), 'github-pages');
    expect((deploy['permissions'] as YamlMap)['pages'], 'write');
    expect((deploy['permissions'] as YamlMap)['id-token'], 'write');
    expect(
      namedStep(deploy, 'Deploy public site')['uses'],
      matches(RegExp(r'^actions/deploy-pages@[0-9a-f]{40}$')),
    );
    final String buildCommands = steps(
      build,
    ).map((YamlMap step) => step['run']?.toString() ?? '').join('\n');
    expect(buildCommands, contains('No verified web app is published here'));
    expect(buildCommands, isNot(contains('flutter build')));
    expect(buildCommands, isNot(contains('CHRONOSPARK_APP_FLAVOR=prod')));
  });

  test('actionlint knows the legitimate self-hosted labels', () {
    final YamlMap config = loadYaml(read('.github/actionlint.yaml')) as YamlMap;
    final YamlMap runner = config['self-hosted-runner'] as YamlMap;
    expect(
      runner['labels'] as YamlList,
      containsAll(<String>['android', 'maestro']),
    );
  });

  test('local secret guards cover the whole repository and fail closed', () {
    final String repositoryGuard = read('scripts/security_secret_guard.ps1');
    final String contentGuard = read('scripts/secret_content_guard.ps1');
    final String strictGate = read('scripts/strict_gate.ps1');

    expect(repositoryGuard, contains('--others --exclude-standard'));
    expect(repositoryGuard, contains(r'\.env(?:\..+)?'));
    expect(repositoryGuard, contains('jks|keystore|p12|pfx|key'));
    expect(contentGuard, contains('--others --exclude-standard'));
    expect(contentGuard, contains(r'gh[pousr]_'));
    expect(contentGuard, contains('github_pat_'));
    expect(contentGuard, contains("'.sql'"));
    expect(contentGuard, contains("'.plist'"));
    expect(contentGuard, contains('git log --no-textconv'));
    expect(contentGuard, contains("throw 'git history scan failed.'"));
    expect(
      strictGate,
      contains('dart run tool/validate_github_workflows.dart'),
    );
  });

  test('repository exposes one canonical root MIT license', () {
    expect(File('LICENSE').existsSync(), isTrue);
    expect(File('LICENSE.md').existsSync(), isFalse);
    expect(read('LICENSE'), startsWith('MIT License'));
    expect(
      read('assets/legal/license.html'),
      contains('fantastic-guacamole/blob/main/LICENSE'),
    );
    expect(
      read('.gitignore').split(RegExp(r'\r?\n')),
      isNot(contains('pubspec.lock')),
    );
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
      final List<String> firebaseProjectIds = RegExp(
        r"projectId: '([^']+)'",
      ).allMatches(firebase).map((Match match) => match.group(1)!).toList();
      expect(firebaseProjectIds, hasLength(5));
      expect(firebaseProjectIds.toSet(), <String>{
        FirebaseIdentity.expectedProjectId,
      });
    },
  );

  test('advanced CodeQL workflow stays retired under default setup', () {
    expect(File('.github/workflows/codeql.yml').existsSync(), isFalse);
    final List<String> actionNames = <String>[];
    for (final File file in Directory(
      '.github/workflows',
    ).listSync().whereType<File>()) {
      final YamlMap document = loadYaml(file.readAsStringSync()) as YamlMap;
      for (final Object? value in jobs(document).values) {
        final YamlMap currentJob = value as YamlMap;
        final Object? stepValues = currentJob['steps'];
        if (stepValues is YamlList) {
          actionNames.addAll(
            stepValues.whereType<YamlMap>().map(
              (YamlMap step) => step['uses']?.toString() ?? '',
            ),
          );
        }
      }
    }
    expect(
      actionNames.where(
        (String uses) => uses.startsWith('github/codeql-action/'),
      ),
      isEmpty,
    );
  });

  test('runtime and golden workflows remain evidence-only', () {
    final YamlMap maestro = job(workflow('maestro-runtime.yml'), 'runtime');
    final YamlMap goldens = job(
      workflow('update-goldens.yml'),
      'update-goldens',
    );
    expect(
      maestro['runs-on'] as YamlList,
      containsAll(<String>['self-hosted', 'android', 'maestro']),
    );
    expect(
      steps(
        maestro,
      ).map((YamlMap step) => step['run']?.toString() ?? '').join('\n'),
      isNot(contains('flutter build')),
    );
    expect(
      steps(
        goldens,
      ).map((YamlMap step) => step['run']?.toString() ?? '').join('\n'),
      isNot(contains('git push')),
    );
    expect(namedStep(goldens, 'Upload golden update for review'), isNotNull);
  });
}
