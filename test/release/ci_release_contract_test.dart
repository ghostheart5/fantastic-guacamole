import 'dart:io';

import 'package:fantastic_guacamole/config/firebase_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final Directory root = Directory.current;
  const String formatCommand =
      'dart format --output=none --set-exit-if-changed '
      'lib test integration_test tool scripts';
  const String fatalAnalyzeCommand = 'flutter analyze --fatal-infos';
  const String edgeFunctionGateCommand =
      './scripts/edge_function_gate.ps1 -RunTests';
  const String edgeFunctionGateContractCommand =
      './scripts/edge_function_gate_contract.ps1';
  const String boundedCoverageCommand =
      'dart run tool/run_flutter_tests.dart --report '
      'artifacts/flutter-test-evidence/flutter-tests.jsonl --manifest '
      'artifacts/flutter-test-evidence/flutter-tests-manifest.json '
      '--timeout-seconds 3600 -- test --no-pub --coverage --concurrency=1';

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

  Set<String> commands(YamlMap currentJob) =>
      steps(currentJob).expand<String>((YamlMap step) {
        final Object? run = step['run'];
        if (run is! String) {
          return const <String>[];
        }
        return run
            .split(RegExp(r'\r?\n'))
            .map((String line) => line.trim())
            .where((String line) => line.isNotEmpty);
      }).toSet();

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

  test('primary CI separates rerunnable categories behind one aggregate', () {
    final YamlMap ci = workflow('ci.yml');
    final YamlMap triggers = ci['on'] as YamlMap;
    final YamlMap push = triggers['push'] as YamlMap;
    final YamlMap pullRequest = triggers['pull_request'] as YamlMap;
    expect(push.containsKey('paths-ignore'), isFalse);
    expect(pullRequest.containsKey('paths-ignore'), isFalse);
    expect(triggers.containsKey('workflow_call'), isTrue);

    final YamlMap staticJob = job(ci, 'static-policy');
    final YamlMap flutterJob = job(ci, 'flutter-tests');
    final YamlMap integrationJob = job(ci, 'linux-integration');
    final YamlMap windowsJob = job(ci, 'windows-goldens');
    final YamlMap aggregate = job(ci, 'test');

    expect(
      commands(staticJob),
      containsAll(<String>[
        formatCommand,
        fatalAnalyzeCommand,
        'dart run tool/validate_github_workflows.dart',
        './scripts/powershell_parse_gate.ps1',
        './scripts/version_consistency_guard_contract.ps1',
      ]),
    );
    expect(commands(flutterJob), contains(boundedCoverageCommand));
    expect(flutterJob['timeout-minutes'], 90);
    expect(
      commands(integrationJob),
      contains('bash ./scripts/run_linux_integration_tests.sh'),
    );
    expect(integrationJob['timeout-minutes'], 60);
    expect(windowsJob['runs-on'], 'windows-2022');
    expect(windowsJob['timeout-minutes'], 45);
    expect(
      ((namedStep(flutterJob, 'Upload Flutter test evidence')['with']
              as YamlMap)['path'])
          .toString(),
      contains('test/**/failures/**'),
    );
    expect(
      ((namedStep(windowsJob, 'Upload Windows golden evidence')['with']
              as YamlMap)['path'])
          .toString(),
      contains('test/**/failures/**'),
    );
    expect(aggregate['name'], 'Analyze & Test');
    expect(aggregate['if'], 'always()');
    expect((aggregate['needs'] as YamlList).toSet(), <Object?>{
      'static-policy',
      'flutter-tests',
      'linux-integration',
      'windows-goldens',
    });
    expect(
      namedStep(staticJob, 'Verify golden comparison contract')['run'],
      './scripts/golden_assertion_guard.ps1',
    );
    expect(
      namedStep(staticJob, 'Lint GitHub Actions workflows')['run'],
      r'$ACTIONLINT -no-color',
    );
    expect(
      commands(staticJob),
      isNot(contains(edgeFunctionGateCommand)),
      reason: 'Backend tests have one dedicated workflow authority.',
    );
    expect(
      commands(staticJob),
      isNot(contains(edgeFunctionGateContractCommand)),
      reason: 'The Deno-backed failure contract runs with the database job.',
    );
  });

  test('database CI retains structured exact-source and Edge evidence', () {
    final YamlMap databaseJob = job(
      workflow('supabase-database.yml'),
      'database',
    );
    expect(databaseJob['timeout-minutes'], 75);
    expect(commands(databaseJob), contains(edgeFunctionGateContractCommand));
    expect(
      commands(databaseJob),
      contains('./scripts/verify_database_evidence.ps1'),
    );
    for (final String stepName in <String>[
      'Type-check and test Edge Functions',
      'Start disposable Supabase backend',
      'Run database contracts',
      'Lint public database schema',
      'Stop disposable Supabase backend',
      'Upload database and Edge evidence',
    ]) {
      expect(namedStep(databaseJob, stepName)['timeout-minutes'], isNotNull);
    }
    final YamlMap upload = namedStep(
      databaseJob,
      'Upload database and Edge evidence',
    );
    expect(upload['if'], 'always()');
    final YamlMap uploadWith = upload['with'] as YamlMap;
    expect(uploadWith['if-no-files-found'], 'error');
    expect(
      uploadWith['path'].toString(),
      allOf(
        contains('artifacts/database-evidence/**'),
        contains('coverage/edge-function-tests.junit.xml'),
      ),
    );
  });

  test(
    'Linux integration has per-file and total budgets below the job cap',
    () {
      final String runner = read('scripts/run_linux_integration_tests.sh');
      expect(runner, contains('shopt -s nullglob globstar'));
      expect(runner, contains('integration_test/**/*_test.dart'));
      expect(runner, contains(r'CHRONOSPARK_INTEGRATION_TIMEOUT_SECONDS:-600'));
      expect(
        runner,
        contains(r'CHRONOSPARK_INTEGRATION_TOTAL_TIMEOUT_SECONDS:-1800'),
      );
      expect(runner, contains(r'remaining_seconds=$((total_timeout_seconds'));
      expect(
        runner,
        contains(r'--timeout-seconds "$effective_timeout_seconds"'),
      );
    },
  );

  test('coverage policy recursively counts app and host integration tests', () {
    final String guard = read('scripts/coverage_guard.ps1');
    expect(
      RegExp(
        r"Get-ChildItem -Path \$appIntegrationTestsPath .* -Recurse",
      ).hasMatch(guard),
      isTrue,
    );
    expect(
      RegExp(
        r"Get-ChildItem -Path \$hostIntegrationTestsPath .* -Recurse",
      ).hasMatch(guard),
      isTrue,
    );
  });

  test('golden updates run independently on Linux and Windows', () {
    final YamlMap updateJob = job(
      workflow('update-goldens.yml'),
      'update-goldens',
    );
    final YamlMap strategy = updateJob['strategy'] as YamlMap;
    final YamlList include =
        (strategy['matrix'] as YamlMap)['include'] as YamlList;
    expect(
      include
          .whereType<YamlMap>()
          .map((YamlMap entry) => entry['runner'])
          .toSet(),
      <Object?>{'ubuntu-24.04', 'windows-2022'},
    );
    expect(updateJob['runs-on'], r'${{ matrix.runner }}');
    final YamlMap updateCheckout = namedStep(updateJob, 'Checkout');
    expect((updateCheckout['with'] as YamlMap)['ref'], r'${{ github.sha }}');
    final YamlMap provenance = namedStep(
      updateJob,
      'Record exact checked-out source',
    );
    expect(provenance['run'], contains(r'git rev-parse HEAD'));
    expect(
      provenance['run'],
      contains(r'$actualCommit -cne $env:RUN_CONTEXT_SHA'),
    );
    expect(provenance['run'], contains('actualCommit = \$actualCommit'));
    expect(
      namedStep(updateJob, 'Verify dependency lock is unchanged')['run'],
      'git diff --exit-code -- pubspec.lock',
    );
    final YamlMap upload = namedStep(
      updateJob,
      'Upload golden update for review',
    );
    expect(
      (upload['with'] as YamlMap)['name'],
      contains(r'${{ matrix.platform }}'),
    );
    expect(
      (upload['with'] as YamlMap)['path'].toString(),
      contains('exact-commit.json'),
    );
  });

  test('extended Dart validation delegates to canonical CI', () {
    final YamlMap canonical = job(workflow('dart.yml'), 'canonical-ci');
    expect(canonical['uses'], './.github/workflows/ci.yml');
    expect(canonical.containsKey('steps'), isFalse);
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
        'linux-release.yml:build-and-release',
        'main.yml:deploy',
      }),
    );
    expect(protectedJobs, isNot(contains('dart.yml:canonical-ci')));
    expect(protectedJobs, isNot(contains('maestro-runtime.yml:runtime')));
  });

  test(
    'Android release parses quality, provenance, signing, and publish gates',
    () {
      final YamlMap android = workflow('android-release.yml');
      final YamlMap quality = job(android, 'quality-gate');
      final YamlMap database = job(android, 'database-gate');
      final YamlMap runtime = job(android, 'runtime-gate');
      final YamlMap build = job(android, 'build-aab');
      final YamlMap publish = job(android, 'publish-release');
      expect(quality['uses'], './.github/workflows/ci.yml');
      expect(database['uses'], './.github/workflows/supabase-database.yml');
      expect(runtime['uses'], './.github/workflows/maestro-runtime.yml');
      expect((build['needs'] as YamlList).toSet(), <Object?>{
        'quality-gate',
        'database-gate',
        'runtime-gate',
      });
      expect(publish['needs'], 'build-aab');
      expect(environmentName(build), 'production');
      expect(environmentName(publish), 'production');

      final List<YamlMap> buildSteps = steps(build);
      expect(commands(build), isNot(contains(formatCommand)));
      expect(commands(build), isNot(contains(fatalAnalyzeCommand)));
      expect(commands(build), isNot(contains(edgeFunctionGateCommand)));
      expect(
        commands(
          build,
        ).where((String value) => value.startsWith('flutter test')),
        isEmpty,
        reason: 'The exact-SHA quality gate owns generic test execution.',
      );
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
    final YamlMap pullRequest = triggers['pull_request'] as YamlMap;
    expect((push['branches'] as YamlList), contains('main'));
    expect((push['paths'] as YamlList), contains('site/**'));
    expect((push['paths'] as YamlList), contains('web/delete-account/**'));
    expect((pullRequest['branches'] as YamlList), contains('main'));
    expect(pullRequest.containsKey('paths'), isFalse);

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

  test('actionlint is checksum pinned and runs automatically', () {
    final YamlMap staticJob = job(workflow('ci.yml'), 'static-policy');
    final YamlMap install = namedStep(
      staticJob,
      'Install checksum-verified actionlint',
    );
    final YamlMap installEnvironment = install['env'] as YamlMap;
    expect(installEnvironment['ACTIONLINT_VERSION'], '1.7.12');
    expect(
      installEnvironment['ACTIONLINT_ARCHIVE_SHA256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
    expect(install['run'], contains('sha256sum --check --strict'));
    expect(
      namedStep(staticJob, 'Lint GitHub Actions workflows')['run'],
      r'$ACTIONLINT -no-color',
    );
    expect(File('.github/workflows/jekyll-docker.yml').existsSync(), isFalse);
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

  test('runtime workflow builds exact source and goldens retain failures', () {
    final YamlMap maestro = job(workflow('maestro-runtime.yml'), 'runtime');
    final YamlMap goldens = job(
      workflow('update-goldens.yml'),
      'update-goldens',
    );
    expect(goldens['runs-on'], r'${{ matrix.runner }}');
    expect(maestro['runs-on'], 'ubuntu-24.04');
    final YamlMap runtimeWorkflow = workflow('maestro-runtime.yml');
    final YamlMap runtimeTriggers = runtimeWorkflow['on'] as YamlMap;
    expect(runtimeTriggers.containsKey('workflow_call'), isTrue);
    expect(
      (runtimeTriggers['push'] as YamlMap)['branches'] as YamlList,
      <Object?>['main'],
    );
    final YamlMap emulatorStep = steps(maestro).singleWhere(
      (YamlMap step) =>
          step['uses']?.toString().toLowerCase().startsWith(
            'reactivecircus/android-emulator-runner@',
          ) ==
          true,
    );
    final String runtimeScript = (emulatorStep['with'] as YamlMap)['script']
        .toString();
    final YamlMap acceleration = namedStep(
      maestro,
      'Enable and verify hardware acceleration',
    );
    expect(
      steps(maestro).indexOf(acceleration),
      lessThan(steps(maestro).indexOf(emulatorStep)),
    );
    expect(acceleration['timeout-minutes'], 2);
    expect(acceleration['run'], contains('test -c /dev/kvm'));
    expect(acceleration['run'], contains('sudo setfacl'));
    expect(
      acceleration['run'],
      contains('test -r /dev/kvm && test -w /dev/kvm'),
    );
    expect(acceleration['run'], isNot(contains('-accel-check')));
    expect(
      (emulatorStep['with'] as YamlMap)['pre-emulator-launch-script'],
      contains('-accel-check'),
    );
    expect(
      (emulatorStep['with'] as YamlMap)['disable-linux-hw-accel'],
      isFalse,
    );
    expect(runtimeScript, contains('run_maestro_android_evidence.ps1'));
    expect(runtimeScript, contains('-DeviceSerial emulator-5554'));
    expect(runtimeScript, contains(r'-ExpectedCommit "${{ github.sha }}"'));
    final YamlMap runtimeEvidence = namedStep(
      maestro,
      'Verify source-bound Maestro evidence',
    );
    expect(runtimeEvidence['if'], 'always()');
    expect(
      runtimeEvidence['run'],
      contains("manifest.get('apk', {}).get('builtFromCheckout') is not True"),
    );
    expect(
      runtimeEvidence['run'],
      contains("junit['testCases'] != len(flows)"),
    );
    final YamlMap runtimeUpload = namedStep(
      maestro,
      'Upload complete Maestro evidence',
    );
    expect(runtimeUpload['if'], 'always()');
    expect((runtimeUpload['with'] as YamlMap)['if-no-files-found'], 'error');
    expect(maestro['timeout-minutes'], 85);
    expect(runtimeUpload['timeout-minutes'], 5);
    expect(
      steps(
        goldens,
      ).map((YamlMap step) => step['run']?.toString() ?? '').join('\n'),
      isNot(contains('git push')),
    );
    expect(
      namedStep(goldens, 'Verify golden comparison contract')['run'],
      './scripts/golden_assertion_guard.ps1',
    );
    expect(
      namedStep(goldens, 'Capture candidate golden diff')['if'],
      'always()',
    );
    final YamlMap goldenUpload = namedStep(
      goldens,
      'Upload golden update for review',
    );
    expect(goldenUpload['if'], 'always()');
    expect((goldenUpload['with'] as YamlMap)['if-no-files-found'], 'error');
    expect(
      (goldenUpload['with'] as YamlMap)['path'].toString(),
      contains('test/**/failures/**'),
    );
  });

  test('PR policy authorizes the immutable PR author identity', () {
    final YamlMap policy = job(
      workflow('pr-policy.yml'),
      'enforce-maintainer-only',
    );
    final YamlMap step = namedStep(policy, 'Enforce maintainer-only PR policy');
    final YamlMap environment = step['env'] as YamlMap;
    final String allowedIds =
        (environment['ALLOWED_PR_AUTHOR_IDS'] ??
                environment['ALLOWED_PR_AUTHOR_ID'])
            .toString();
    expect(allowedIds, contains('294620552'));
    expect(allowedIds, contains('198982749'));
    expect(
      environment['PR_AUTHOR_ID'],
      r'${{ github.event.pull_request.user.id }}',
    );
    expect(step['run'], contains(r'$PR_AUTHOR_ID'));
    expect(step['run'], isNot(contains('github.triggering_actor')));
  });
}
