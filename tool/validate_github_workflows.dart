import 'dart:io';

import 'package:yaml/yaml.dart';

const String _flutterVersion = '3.44.6';
const String _formatCommand =
    'dart format --output=none --set-exit-if-changed '
    'lib test integration_test tool scripts';
const String _fatalAnalyzeCommand = 'flutter analyze --fatal-infos';
const String _edgeFunctionGateCommand =
    './scripts/edge_function_gate.ps1 -RunTests';

const Map<String, List<({String label, String command})>>
_requiredPrimaryCiGatesByJob = <String, List<({String label, String command})>>{
  'static-policy': <({String label, String command})>[
    (label: 'architecture boundary', command: './check_architecture.ps1'),
    (
      label: 'Maestro flow contract',
      command: 'dart run tool/validate_maestro_flows.dart',
    ),
    (
      label: 'golden comparison contract',
      command: './scripts/golden_assertion_guard.ps1',
    ),
    (label: 'dependency audit', command: './scripts/dependency_audit.ps1'),
    (label: 'GitHub workflow lint', command: r'$ACTIONLINT -no-color'),
    (
      label: 'PowerShell parse gate',
      command: './scripts/powershell_parse_gate.ps1',
    ),
    (
      label: 'coverage guard contract',
      command: './scripts/coverage_guard_contract.ps1',
    ),
  ],
  'flutter-tests': <({String label, String command})>[
    (
      label: 'full Flutter coverage test',
      command:
          'dart run tool/run_flutter_tests.dart --report artifacts/flutter-test-evidence/flutter-tests.jsonl --manifest artifacts/flutter-test-evidence/flutter-tests-manifest.json --timeout-seconds 3600 -- test --no-pub --coverage --concurrency=1',
    ),
    (
      label: 'QA compile-time configuration',
      command:
          'dart run tool/run_flutter_tests.dart --report artifacts/flutter-test-evidence/qa-config-tests.jsonl --manifest artifacts/flutter-test-evidence/qa-config-tests-manifest.json --timeout-seconds 600 -- test/config/env_mode_resolution_test.dart --no-pub --dart-define-from-file=tool/qa_defines.json',
    ),
    (
      label: 'coverage enforcement',
      command: './scripts/coverage_guard.ps1 -Mode ratchet',
    ),
  ],
  'linux-integration': <({String label, String command})>[
    (
      label: 'Linux integration',
      command: 'bash ./scripts/run_linux_integration_tests.sh',
    ),
  ],
  'windows-goldens': <({String label, String command})>[
    (
      label: 'Windows golden comparison',
      command:
          'dart run tool/run_flutter_tests.dart --report artifacts/windows-golden-evidence/golden-tests.jsonl --manifest artifacts/windows-golden-evidence/golden-tests-manifest.json --timeout-seconds 1200 -- test/features/auth/login_screen_golden_test.dart test/features/home/first_use_context_offer_card_test.dart test/features/nexus/nexus_screen_golden_test.dart test/features/settings/settings_screen_test.dart --no-pub --concurrency=1',
    ),
  ],
};

const List<({String label, String command})> _requiredDatabaseGates =
    <({String label, String command})>[
      (
        label: 'Edge Function gate failure contract',
        command: './scripts/edge_function_gate_contract.ps1',
      ),
      (label: 'Edge Function contract', command: _edgeFunctionGateCommand),
      (
        label: 'database evidence verification',
        command: './scripts/verify_database_evidence.ps1',
      ),
      (
        label: 'migration replay policy',
        command: './scripts/supabase_migration_policy_contract.ps1',
      ),
      (label: 'disposable backend startup', command: 'supabase start'),
      (label: 'database contract test', command: 'supabase test db'),
      (
        label: 'database schema lint',
        command: 'supabase db lint --local --schema public --fail-on error',
      ),
      (
        label: 'disposable backend shutdown',
        command: 'supabase stop --no-backup',
      ),
    ];

const Map<String, Map<String, Set<String>>> _allowedJobWrites =
    <String, Map<String, Set<String>>>{
      'android-release.yml': <String, Set<String>>{
        'publish-release': <String>{'contents'},
      },
      'linux-release.yml': <String, Set<String>>{
        'build-and-release': <String>{'contents'},
      },
      'main.yml': <String, Set<String>>{
        'deploy': <String>{'pages', 'id-token'},
      },
    };

const Set<String> _publishingActions = <String>{
  'actions/deploy-pages',
  'softprops/action-gh-release',
};

void main() {
  final Directory workflowDirectory = Directory('.github/workflows');
  final List<File> workflowFiles =
      workflowDirectory
          .listSync()
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.yml') || file.path.endsWith('.yaml'),
          )
          .toList()
        ..sort((File left, File right) => left.path.compareTo(right.path));
  final List<String> failures = <String>[];

  if (workflowFiles.isEmpty) {
    failures.add('No GitHub workflow files were found.');
  }

  for (final File file in workflowFiles) {
    _validateWorkflow(file, failures);
  }
  _validatePrimaryCi(failures);
  _validateSupabaseDatabase(failures);
  _validateStaticQualityGates(failures);
  _validateAndroidRelease(failures);
  _validateMaestroRuntime(failures);
  _validatePrPolicy(failures);

  if (failures.isNotEmpty) {
    stderr.writeln('GitHub workflow guard failed:');
    for (final String failure in failures.toSet().toList()..sort()) {
      stderr.writeln(' - $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'GitHub workflow guard passed for ${workflowFiles.length} workflows.',
  );
}

void _validateWorkflow(File file, List<String> failures) {
  final String fileName = file.uri.pathSegments.last;
  final String relativePath = '.github/workflows/$fileName';
  final YamlMap? document = _loadWorkflow(file, failures);
  if (document == null) {
    return;
  }

  if (!document.containsKey('on')) {
    failures.add('$relativePath must declare explicit triggers.');
  }
  if (_inheritsAllSecrets(document)) {
    failures.add('$relativePath must not inherit all caller secrets.');
  }

  final Object? workflowPermissions = document['permissions'];
  _validatePermissions(
    file: relativePath,
    location: 'workflow',
    permissions: workflowPermissions,
    allowedWrites: const <String>{},
    failures: failures,
  );

  final Object? jobsValue = document['jobs'];
  if (jobsValue is! YamlMap || jobsValue.isEmpty) {
    failures.add('$relativePath must declare at least one job.');
    return;
  }

  for (final MapEntry<Object?, Object?> jobEntry in jobsValue.entries) {
    final String jobName = jobEntry.key.toString();
    final Object? jobValue = jobEntry.value;
    if (jobValue is! YamlMap) {
      failures.add('$relativePath job $jobName must be a mapping.');
      continue;
    }

    final Set<String> allowedWrites =
        _allowedJobWrites[fileName]?[jobName] ?? const <String>{};
    final Object? jobPermissions = jobValue.containsKey('permissions')
        ? jobValue['permissions']
        : workflowPermissions;
    if (jobValue.containsKey('permissions')) {
      _validatePermissions(
        file: relativePath,
        location: 'job $jobName',
        permissions: jobValue['permissions'],
        allowedWrites: allowedWrites,
        failures: failures,
      );
    }

    _validateUses(
      file: relativePath,
      location: 'job $jobName',
      uses: jobValue['uses'],
      configuration: jobValue,
      failures: failures,
    );

    final Object? runsOn = jobValue['runs-on'];
    if (runsOn != null) {
      final Object? timeout = jobValue['timeout-minutes'];
      if (timeout is! int || timeout < 1 || timeout > 120) {
        failures.add(
          '$relativePath job $jobName must set timeout-minutes from 1 to 120.',
        );
      }
      _validateRunner(
        file: relativePath,
        jobName: jobName,
        runsOn: runsOn,
        strategy: jobValue['strategy'],
        failures: failures,
      );
    } else if (!jobValue.containsKey('uses')) {
      failures.add('$relativePath job $jobName must declare runs-on or uses.');
    }

    final Object? stepsValue = jobValue['steps'];
    if (stepsValue != null && stepsValue is! YamlList) {
      failures.add('$relativePath job $jobName steps must be a list.');
      continue;
    }
    if (stepsValue is YamlList) {
      for (int index = 0; index < stepsValue.length; index += 1) {
        final Object? stepValue = stepsValue[index];
        if (stepValue is! YamlMap) {
          failures.add(
            '$relativePath job $jobName step ${index + 1} must be a mapping.',
          );
          continue;
        }
        _validateUses(
          file: relativePath,
          location: 'job $jobName step ${index + 1}',
          uses: stepValue['uses'],
          configuration: stepValue,
          failures: failures,
        );
        final Object? run = stepValue['run'];
        if (run is String && run.contains(r'${{ secrets.')) {
          failures.add(
            '$relativePath job $jobName step ${index + 1} must pass secrets through env, not interpolate them in run.',
          );
        }
      }
    }

    final bool receivesSecrets = _containsSecretExpression(jobValue);
    final bool publishes =
        _hasWritePermission(jobPermissions) ||
        _containsPublishOperation(jobValue);
    if (receivesSecrets || publishes) {
      final String requiredEnvironment =
          fileName == 'main.yml' && jobName == 'deploy'
          ? 'github-pages'
          : 'production';
      if (_environmentName(jobValue['environment']) != requiredEnvironment) {
        failures.add(
          '$relativePath job $jobName must use the protected $requiredEnvironment environment because it ${receivesSecrets ? 'receives secrets' : 'publishes externally'}.',
        );
      }
    }
  }
}

YamlMap? _loadWorkflow(File file, List<String> failures) {
  final String relativePath = '.github/workflows/${file.uri.pathSegments.last}';
  try {
    final Object? document = loadYaml(file.readAsStringSync());
    if (document is YamlMap) {
      return document;
    }
    failures.add('$relativePath must contain a YAML mapping.');
  } on YamlException catch (error) {
    failures.add('$relativePath is invalid YAML: ${error.message}');
  }
  return null;
}

void _validatePermissions({
  required String file,
  required String location,
  required Object? permissions,
  required Set<String> allowedWrites,
  required List<String> failures,
}) {
  if (permissions is! YamlMap) {
    failures.add('$file $location must declare an explicit permission map.');
    return;
  }
  for (final MapEntry<Object?, Object?> entry in permissions.entries) {
    final String permission = entry.key.toString();
    final String access = entry.value.toString();
    if (!const <String>{'read', 'write', 'none'}.contains(access)) {
      failures.add('$file $location has invalid $permission access "$access".');
    }
    if (access == 'write' && !allowedWrites.contains(permission)) {
      failures.add('$file $location must not grant $permission: write.');
    }
  }
}

void _validateRunner({
  required String file,
  required String jobName,
  required Object runsOn,
  required Object? strategy,
  required List<String> failures,
}) {
  if (runsOn is YamlList) {
    if (!runsOn
        .map((Object? value) => value.toString())
        .contains('self-hosted')) {
      failures.add('$file job $jobName uses an unsupported runner label list.');
    }
    return;
  }
  if (runsOn is! String) {
    failures.add('$file job $jobName has an unsupported runs-on value.');
    return;
  }
  if (runsOn == 'ubuntu-24.04' ||
      runsOn == 'macos-15' ||
      runsOn == 'windows-2022') {
    return;
  }
  if (runsOn.contains(r'${{ matrix.runner }}')) {
    final Object? matrix = strategy is YamlMap ? strategy['matrix'] : null;
    final Object? include = matrix is YamlMap ? matrix['include'] : null;
    if (include is! YamlList || include.isEmpty) {
      failures.add('$file job $jobName runner matrix must have fixed entries.');
      return;
    }
    for (final Object? item in include) {
      final Object? runner = item is YamlMap ? item['runner'] : null;
      if (runner != 'ubuntu-24.04' &&
          runner != 'macos-15' &&
          runner != 'windows-2022') {
        failures.add(
          '$file job $jobName matrix contains mutable or unsupported runner "$runner".',
        );
      }
    }
    return;
  }
  failures.add(
    '$file job $jobName uses mutable or unsupported runner "$runsOn".',
  );
}

void _validateUses({
  required String file,
  required String location,
  required Object? uses,
  required YamlMap configuration,
  required List<String> failures,
}) {
  if (uses is! String || uses.startsWith('./')) {
    return;
  }
  if (uses.startsWith('docker://')) {
    if (!RegExp(r'^docker://[^@\s]+@sha256:[0-9a-f]{64}$').hasMatch(uses)) {
      failures.add('$file $location must pin Docker image "$uses" by digest.');
    }
    return;
  }

  final Match? action = RegExp(r'^([^@\s]+)@([0-9a-f]{40})$').firstMatch(uses);
  if (action == null) {
    failures.add('$file $location must pin external action "$uses" to a SHA.');
    return;
  }

  final String actionName = action.group(1)!;
  final Object? withValue = configuration['with'];
  final YamlMap? withMap = withValue is YamlMap ? withValue : null;
  if (actionName == 'actions/checkout' &&
      withMap?['persist-credentials'] != false) {
    failures.add(
      '$file $location must set checkout persist-credentials to false.',
    );
  }
  if (actionName == 'subosito/flutter-action' &&
      withMap?['flutter-version'] != _flutterVersion) {
    failures.add('$file $location must pin Flutter to $_flutterVersion.');
  }
}

void _validatePrimaryCi(List<String> failures) {
  final File file = File('.github/workflows/ci.yml');
  final YamlMap? document = _loadWorkflow(file, failures);
  if (document == null) {
    return;
  }
  _validatePrimaryCiDocument(document, failures);
}

/// Validates the primary CI contract from source for focused regression tests.
List<String> validatePrimaryCiSource(String source) {
  final List<String> failures = <String>[];
  try {
    final Object? document = loadYaml(source);
    if (document is! YamlMap) {
      failures.add('Primary CI must contain a YAML mapping.');
      return failures;
    }
    _validatePrimaryCiDocument(document, failures);
  } on YamlException catch (error) {
    failures.add('Primary CI is invalid YAML: ${error.message}');
  }
  return failures;
}

void _validatePrimaryCiDocument(YamlMap document, List<String> failures) {
  final Object? triggers = document['on'];
  final Object? push = triggers is YamlMap ? triggers['push'] : null;
  final Object? pullRequest = triggers is YamlMap
      ? triggers['pull_request']
      : null;
  if (push is! YamlMap || push.containsKey('paths-ignore')) {
    failures.add('Primary CI must run for workflow-only pushes.');
  }
  if (pullRequest is! YamlMap || pullRequest.containsKey('paths-ignore')) {
    failures.add('Primary CI must run for workflow-only pull requests.');
  }

  final Object? jobsValue = document['jobs'];
  if (jobsValue is! YamlMap) {
    failures.add('Primary CI must declare jobs.');
    return;
  }
  final List<YamlMap> allSteps = jobsValue.values
      .whereType<YamlMap>()
      .expand<YamlMap>((YamlMap job) {
        final Object? steps = job['steps'];
        return steps is YamlList ? steps.whereType<YamlMap>() : <YamlMap>[];
      })
      .toList();
  final bool invokesGuard = allSteps.any(
    (YamlMap step) =>
        step['run'] == 'dart run tool/validate_github_workflows.dart',
  );
  if (!invokesGuard) {
    failures.add('Primary CI must execute the GitHub workflow guard.');
  }

  for (final MapEntry<String, List<({String command, String label})>> entry
      in _requiredPrimaryCiGatesByJob.entries) {
    final Object? jobValue = jobsValue[entry.key];
    final Object? stepsValue = jobValue is YamlMap ? jobValue['steps'] : null;
    final List<YamlMap> steps = stepsValue is YamlList
        ? stepsValue.whereType<YamlMap>().toList()
        : <YamlMap>[];
    if (jobValue is! YamlMap || stepsValue is! YamlList) {
      failures.add(
        'Primary CI required job ${entry.key} must declare executable steps.',
      );
    } else if (_isFailOpenStep(jobValue)) {
      failures.add(
        'Primary CI required job ${entry.key} must not use continue-on-error.',
      );
    }
    _validateRequiredGateSteps(
      contract: 'Primary CI',
      steps: steps,
      gates: entry.value,
      failures: failures,
    );
  }

  final Object? aggregateValue = jobsValue['test'];
  if (aggregateValue is! YamlMap) {
    failures.add('Primary CI must retain the Analyze & Test aggregate job.');
    return;
  }
  if (aggregateValue['name'] != 'Analyze & Test' ||
      aggregateValue['if'] != 'always()') {
    failures.add(
      'Primary CI aggregate must be named Analyze & Test and run with if: always().',
    );
  }
  if (_isFailOpenStep(aggregateValue)) {
    failures.add(
      'Primary CI Analyze & Test aggregate must not use continue-on-error.',
    );
  }
  const Set<String> requiredNeeds = <String>{
    'static-policy',
    'flutter-tests',
    'linux-integration',
    'windows-goldens',
  };
  final Object? needsValue = aggregateValue['needs'];
  final Set<String> actualNeeds = needsValue is YamlList
      ? needsValue.map((Object? value) => value.toString()).toSet()
      : <String>{if (needsValue != null) needsValue.toString()};
  if (!actualNeeds.containsAll(requiredNeeds)) {
    failures.add(
      'Primary CI Analyze & Test aggregate must depend on every required category job.',
    );
  }
  final Object? aggregateStepsValue = aggregateValue['steps'];
  final List<YamlMap> aggregateSteps = aggregateStepsValue is YamlList
      ? aggregateStepsValue.whereType<YamlMap>().toList()
      : <YamlMap>[];
  final bool failClosed = aggregateSteps.any((YamlMap step) {
    final String run = step['run']?.toString() ?? '';
    final Object? env = step['env'];
    return env is YamlMap &&
        requiredNeeds.every(
          (String job) => env.values.any(
            (Object? value) => value.toString() == '\${{ needs.$job.result }}',
          ),
        ) &&
        run.contains(r'if [ "$result" != "success" ]') &&
        run.contains('exit 1') &&
        !_isFailOpenStep(step);
  });
  if (!failClosed) {
    failures.add(
      'Primary CI Analyze & Test aggregate must fail closed on every dependency result.',
    );
  }
}

bool _isFailOpenStep(YamlMap step) {
  return step.containsKey('continue-on-error') &&
      step['continue-on-error'] != false;
}

void _validateSupabaseDatabase(List<String> failures) {
  final File file = File('.github/workflows/supabase-database.yml');
  final YamlMap? document = _loadWorkflow(file, failures);
  if (document == null) {
    return;
  }
  _validateSupabaseDatabaseDocument(document, failures);
}

/// Validates the dedicated database workflow from source for focused tests.
List<String> validateSupabaseDatabaseSource(String source) {
  final List<String> failures = <String>[];
  try {
    final Object? document = loadYaml(source);
    if (document is! YamlMap) {
      failures.add('Supabase database workflow must contain a YAML mapping.');
      return failures;
    }
    _validateSupabaseDatabaseDocument(document, failures);
  } on YamlException catch (error) {
    failures.add(
      'Supabase database workflow is invalid YAML: ${error.message}',
    );
  }
  return failures;
}

void _validateSupabaseDatabaseDocument(
  YamlMap document,
  List<String> failures,
) {
  final Object? triggersValue = document['on'];
  if (triggersValue is! YamlMap) {
    failures.add(
      'Supabase database workflow must declare explicit workflow triggers.',
    );
  } else {
    if (!_isMainOnlyBranchTrigger(triggersValue['push'])) {
      failures.add(
        'Supabase database workflow push trigger must target only main.',
      );
    }
    if (!_isMainOnlyBranchTrigger(triggersValue['pull_request'])) {
      failures.add(
        'Supabase database workflow pull request trigger must target only main.',
      );
    }
    if (!triggersValue.containsKey('workflow_call')) {
      failures.add(
        'Supabase database workflow must retain the workflow_call trigger.',
      );
    }
  }

  final Object? jobsValue = document['jobs'];
  final Object? databaseJob = jobsValue is YamlMap
      ? jobsValue['database']
      : null;
  final Object? stepsValue = databaseJob is YamlMap
      ? databaseJob['steps']
      : null;
  if (stepsValue is! YamlList) {
    failures.add('Supabase database workflow database job must declare steps.');
    return;
  }
  if (databaseJob is YamlMap && _isFailOpenStep(databaseJob)) {
    failures.add(
      'Supabase database workflow database job must not use continue-on-error.',
    );
  }
  final List<YamlMap> steps = stepsValue.whereType<YamlMap>().toList();
  _validateRequiredGateSteps(
    contract: 'Supabase database workflow',
    steps: steps,
    gates: _requiredDatabaseGates,
    failures: failures,
  );

  final List<YamlMap> stopSteps = _matchingCommandSteps(
    steps,
    'supabase stop --no-backup',
  );
  if (stopSteps.isNotEmpty &&
      !stopSteps.any((YamlMap step) => step['if'] == 'always()')) {
    failures.add(
      'Supabase database workflow shutdown gate must run with if: always().',
    );
  }

  final YamlMap? uploadStep = steps.cast<YamlMap?>().firstWhere(
    (YamlMap? step) => step?['name'] == 'Upload database and Edge evidence',
    orElse: () => null,
  );
  final Object? uploadWith = uploadStep?['with'];
  if (uploadStep == null ||
      uploadStep['if'] != 'always()' ||
      uploadWith is! YamlMap ||
      uploadWith['if-no-files-found'] != 'error' ||
      !(uploadWith['path']?.toString() ?? '').contains(
        'artifacts/database-evidence/**',
      ) ||
      !(uploadWith['path']?.toString() ?? '').contains(
        'coverage/edge-function-tests.junit.xml',
      )) {
    failures.add(
      'Supabase database workflow must always upload exact-source and Edge JUnit evidence.',
    );
  }

  final List<int> gateIndexes = _requiredDatabaseGates
      .map(
        (({String command, String label}) gate) => steps.indexWhere(
          (YamlMap step) => _commandLines(step['run']).contains(gate.command),
        ),
      )
      .where((int index) => index >= 0)
      .toList();
  for (int index = 1; index < gateIndexes.length; index += 1) {
    if (gateIndexes[index] <= gateIndexes[index - 1]) {
      failures.add(
        'Supabase database workflow gates must run in fail-closed lifecycle order.',
      );
      break;
    }
  }
}

bool _isMainOnlyBranchTrigger(Object? trigger) {
  if (trigger is! YamlMap || trigger.containsKey('paths-ignore')) {
    return false;
  }
  final Object? branchesValue = trigger['branches'];
  if (branchesValue is! YamlList) {
    return false;
  }
  final List<String> branches = branchesValue
      .map((Object? branch) => branch.toString())
      .toList();
  return branches.length == 1 && branches.single == 'main';
}

void _validateRequiredGateSteps({
  required String contract,
  required List<YamlMap> steps,
  required List<({String label, String command})> gates,
  required List<String> failures,
}) {
  for (final ({String label, String command}) gate in gates) {
    final List<YamlMap> matchingSteps = _matchingCommandSteps(
      steps,
      gate.command,
    );
    if (matchingSteps.isEmpty) {
      failures.add(
        '$contract must retain the ${gate.label} gate with exact command: ${gate.command}',
      );
      continue;
    }
    if (matchingSteps.any(_isFailOpenStep)) {
      failures.add(
        '$contract ${gate.label} gate must not use continue-on-error.',
      );
    }
    if (gate.label != 'disposable backend shutdown' &&
        matchingSteps.any((YamlMap step) => step.containsKey('if'))) {
      failures.add('$contract ${gate.label} gate must run unconditionally.');
    }
  }
}

List<YamlMap> _matchingCommandSteps(List<YamlMap> steps, String command) {
  return steps.where((YamlMap step) {
    final Object? run = step['run'];
    return run is String && run.trim() == command;
  }).toList();
}

void _validateStaticQualityGates(List<String> failures) {
  const Map<String, String> gatedJobs = <String, String>{
    'ci.yml': 'static-policy',
  };

  for (final MapEntry<String, String> entry in gatedJobs.entries) {
    final File file = File('.github/workflows/${entry.key}');
    final YamlMap? document = _loadWorkflow(file, failures);
    if (document == null) {
      continue;
    }
    final Object? jobsValue = document['jobs'];
    final Object? jobValue = jobsValue is YamlMap
        ? jobsValue[entry.value]
        : null;
    final Object? stepsValue = jobValue is YamlMap ? jobValue['steps'] : null;
    if (stepsValue is! YamlList) {
      failures.add(
        '${entry.key} job ${entry.value} must declare static gates.',
      );
      continue;
    }
    final List<YamlMap> steps = stepsValue.whereType<YamlMap>().toList();
    final Set<String> commands = steps
        .expand<String>((YamlMap step) => _commandLines(step['run']))
        .toSet();

    for (final String command in <String>[
      _formatCommand,
      _fatalAnalyzeCommand,
    ]) {
      if (!commands.contains(command)) {
        failures.add(
          '${entry.key} job ${entry.value} must execute exactly: $command',
        );
      }
    }
  }
}

Iterable<String> _commandLines(Object? run) sync* {
  if (run is! String) {
    return;
  }
  for (final String line in run.split(RegExp(r'\r?\n'))) {
    final String command = line.trim();
    if (command.isNotEmpty) {
      yield command;
    }
  }
}

void _validateAndroidRelease(List<String> failures) {
  final File file = File('.github/workflows/android-release.yml');
  final YamlMap? document = _loadWorkflow(file, failures);
  if (document == null) {
    return;
  }
  final Object? jobsValue = document['jobs'];
  final Object? build = jobsValue is YamlMap ? jobsValue['build-aab'] : null;
  final Object? databaseGate = jobsValue is YamlMap
      ? jobsValue['database-gate']
      : null;
  final Object? runtimeGate = jobsValue is YamlMap
      ? jobsValue['runtime-gate']
      : null;
  final Object? publish = jobsValue is YamlMap
      ? jobsValue['publish-release']
      : null;
  if (build is! YamlMap || publish is! YamlMap) {
    failures.add('Android release must separate build and publish jobs.');
    return;
  }
  if (databaseGate is! YamlMap ||
      databaseGate['uses'] != './.github/workflows/supabase-database.yml') {
    failures.add(
      'Android release must call the reusable Supabase database gate.',
    );
  }
  if (runtimeGate is! YamlMap ||
      runtimeGate['uses'] != './.github/workflows/maestro-runtime.yml') {
    failures.add(
      'Android release must call the reusable exact-build Maestro runtime gate.',
    );
  }
  final Object? needs = build['needs'];
  final Set<String> requiredNeeds = <String>{
    'quality-gate',
    'database-gate',
    'runtime-gate',
  };
  final Set<String> actualNeeds = needs is YamlList
      ? needs.map((Object? value) => value.toString()).toSet()
      : <String>{if (needs != null) needs.toString()};
  if (!actualNeeds.containsAll(requiredNeeds)) {
    failures.add(
      'Android release build must depend on quality, database, and runtime gates.',
    );
  }
  final Object? stepsValue = build['steps'];
  if (stepsValue is! YamlList) {
    failures.add('Android release build job must declare steps.');
    return;
  }
  final List<YamlMap> steps = stepsValue.whereType<YamlMap>().toList();
  int stepIndex(String name) =>
      steps.indexWhere((YamlMap step) => step['name'] == name);

  final int configIndex = stepIndex('Validate production configuration');
  final int backendIndex = stepIndex(
    'Verify live backend, App Links, RTDN, and Play configuration',
  );
  final int signingMaterialIndex = stepIndex('Decode keystore');
  final int buildIndex = stepIndex('Build signed AAB');
  if (configIndex < 0 ||
      backendIndex < 0 ||
      signingMaterialIndex < 0 ||
      buildIndex < 0 ||
      configIndex >= signingMaterialIndex ||
      backendIndex >= signingMaterialIndex ||
      configIndex >= buildIndex ||
      backendIndex >= buildIndex) {
    failures.add(
      'Android production configuration and live backend must be validated before signing material is decoded and before the AAB is built.',
    );
  }

  final YamlMap? checkout = steps.cast<YamlMap?>().firstWhere(
    (YamlMap? step) =>
        step?['uses']?.toString().startsWith('actions/checkout@') == true,
    orElse: () => null,
  );
  final Object? checkoutWith = checkout?['with'];
  if (checkoutWith is! YamlMap || checkoutWith['fetch-depth'] != 0) {
    failures.add('Android release checkout must fetch full tag provenance.');
  }

  final bool requiresAuthorizedTag = steps.any((YamlMap step) {
    final String run = step['run']?.toString() ?? '';
    return run.contains('version_consistency_guard.ps1 -RequireTag');
  });
  if (!requiresAuthorizedTag) {
    failures.add('Android release must require an authorized release tag.');
  }

  final bool hasRunScopedArtifact = steps.any((YamlMap step) {
    final Object? withValue = step['with'];
    return withValue is YamlMap &&
        withValue['name'] ==
            r'chronospark-release-${{ github.run_id }}-${{ github.run_attempt }}';
  });
  if (!hasRunScopedArtifact) {
    failures.add('Android artifacts must use a run-scoped name.');
  }

  const Map<String, String> protectedMaterialSteps = <String, String>{
    'Configure Firebase Android file': 'android/app/google-services.json',
    'Decode keystore': 'android/app/key.jks',
    'Write key.properties': 'android/key.properties',
  };
  for (final MapEntry<String, String> entry in protectedMaterialSteps.entries) {
    final int index = stepIndex(entry.key);
    if (index < 0) {
      failures.add(
        'Android release must retain the ${entry.key} protected-material step.',
      );
      continue;
    }
    final String run = steps[index]['run']?.toString() ?? '';
    if (!run.contains(entry.value)) {
      failures.add(
        'Android release step ${entry.key} must write ${entry.value}.',
      );
    }
    if (!RegExp(r'^\s*umask 077(?:\r?\n|$)').hasMatch(run)) {
      failures.add(
        'Android release step ${entry.key} must establish umask 077 before writing protected material.',
      );
    }
  }

  final bool hasCleanup = steps.any((YamlMap step) {
    final String run = step['run']?.toString() ?? '';
    return step['if'] == 'always()' &&
        run.contains('android/app/key.jks') &&
        run.contains('android/key.properties') &&
        run.contains('android/app/google-services.json') &&
        run.contains('.env');
  });
  if (!hasCleanup) {
    failures.add('Android release must always remove runner-only secrets.');
  }
}

void _validateMaestroRuntime(List<String> failures) {
  final File file = File('.github/workflows/maestro-runtime.yml');
  final YamlMap? document = _loadWorkflow(file, failures);
  if (document == null) {
    return;
  }
  final Object? triggersValue = document['on'];
  if (triggersValue is! YamlMap ||
      !triggersValue.containsKey('workflow_call') ||
      !_isMainOnlyBranchTrigger(triggersValue['push'])) {
    failures.add(
      'Maestro runtime must be reusable and run automatically for main.',
    );
  }
  final Object? jobsValue = document['jobs'];
  final Object? runtimeValue = jobsValue is YamlMap
      ? jobsValue['runtime']
      : null;
  if (runtimeValue is! YamlMap || runtimeValue['runs-on'] != 'ubuntu-24.04') {
    failures.add(
      'Maestro runtime must use the pinned GitHub-hosted Ubuntu runner.',
    );
    return;
  }
  final Object? stepsValue = runtimeValue['steps'];
  final List<YamlMap> steps = stepsValue is YamlList
      ? stepsValue.whereType<YamlMap>().toList()
      : <YamlMap>[];
  final YamlMap? emulatorStep = steps.cast<YamlMap?>().firstWhere(
    (YamlMap? step) =>
        step?['uses']?.toString().toLowerCase().startsWith(
          'reactivecircus/android-emulator-runner@',
        ) ==
        true,
    orElse: () => null,
  );
  final Object? emulatorWith = emulatorStep?['with'];
  final String emulatorScript = emulatorWith is YamlMap
      ? emulatorWith['script']?.toString() ?? ''
      : '';
  if (!emulatorScript.contains('run_maestro_android_evidence.ps1') ||
      !emulatorScript.contains('-DeviceSerial emulator-5554') ||
      !emulatorScript.contains(r'-ExpectedCommit "${{ github.sha }}"')) {
    failures.add(
      'Maestro runtime must build, install, and run source-bound evidence on an explicit emulator.',
    );
  }

  final YamlMap? evidenceStep = steps.cast<YamlMap?>().firstWhere(
    (YamlMap? step) => step?['name'] == 'Verify source-bound Maestro evidence',
    orElse: () => null,
  );
  if (evidenceStep == null ||
      evidenceStep['if'] != 'always()' ||
      !(evidenceStep['run']?.toString() ?? '').contains(
        "manifest.get('status') != 'passed'",
      ) ||
      !(evidenceStep['run']?.toString() ?? '').contains(
        "junit.get('testCases')",
      ) ||
      !(evidenceStep['run']?.toString() ?? '').contains(
        "junit.get('skipped') != 0",
      ) ||
      !(evidenceStep['run']?.toString() ?? '').contains(
        "manifest.get('apk', {}).get('builtFromCheckout') is not True",
      ) ||
      !(evidenceStep['run']?.toString() ?? '').contains(
        "junit['testCases'] != len(flows)",
      ) ||
      !(evidenceStep['run']?.toString() ?? '').contains(
        "logcat.get('status') != 'passed'",
      )) {
    failures.add(
      'Maestro runtime must always verify the source-bound manifest and JUnit result.',
    );
  }

  final YamlMap? uploadStep = steps.cast<YamlMap?>().firstWhere(
    (YamlMap? step) => step?['name'] == 'Upload complete Maestro evidence',
    orElse: () => null,
  );
  final Object? uploadWithValue = uploadStep?['with'];
  if (uploadStep == null ||
      uploadStep['if'] != 'always()' ||
      uploadWithValue is! YamlMap ||
      uploadWithValue['if-no-files-found'] != 'error' ||
      uploadWithValue['path'] != 'artifacts/maestro-ci/**') {
    failures.add('Maestro runtime must always upload complete evidence.');
  }
}

void _validatePrPolicy(List<String> failures) {
  final File file = File('.github/workflows/pr-policy.yml');
  final YamlMap? document = _loadWorkflow(file, failures);
  if (document == null) {
    return;
  }
  final Object? jobsValue = document['jobs'];
  final Object? policyValue = jobsValue is YamlMap
      ? jobsValue['enforce-maintainer-only']
      : null;
  final Object? stepsValue = policyValue is YamlMap
      ? policyValue['steps']
      : null;
  final List<YamlMap> steps = stepsValue is YamlList
      ? stepsValue.whereType<YamlMap>().toList()
      : <YamlMap>[];
  final YamlMap? policyStep = steps.cast<YamlMap?>().firstWhere(
    (YamlMap? step) => step?['name'] == 'Enforce maintainer-only PR policy',
    orElse: () => null,
  );
  final Object? envValue = policyStep?['env'];
  final String run = policyStep?['run']?.toString() ?? '';
  final String allowedIds = envValue is YamlMap
      ? (envValue['ALLOWED_PR_AUTHOR_IDS'] ?? envValue['ALLOWED_PR_AUTHOR_ID'])
                ?.toString() ??
            ''
      : '';
  if (envValue is! YamlMap ||
      !allowedIds.contains('294620552') ||
      !allowedIds.contains('198982749') ||
      envValue['PR_AUTHOR_ID']?.toString() !=
          r'${{ github.event.pull_request.user.id }}' ||
      run.contains('github.triggering_actor') ||
      !run.contains(r'$PR_AUTHOR_ID')) {
    failures.add(
      'PR policy must authorize the immutable pull request author ID.',
    );
  }
}

bool _containsSecretExpression(Object? value) {
  if (value is String) {
    return value.contains(r'${{ secrets.');
  }
  if (value is YamlMap) {
    return value.entries.any(
      (MapEntry<Object?, Object?> entry) =>
          _containsSecretExpression(entry.key) ||
          _containsSecretExpression(entry.value),
    );
  }
  if (value is YamlList) {
    return value.any(_containsSecretExpression);
  }
  return false;
}

bool _inheritsAllSecrets(Object? value) {
  if (value is YamlMap) {
    if (value['secrets'] == 'inherit') {
      return true;
    }
    return value.entries.any(
      (MapEntry<Object?, Object?> entry) =>
          _inheritsAllSecrets(entry.key) || _inheritsAllSecrets(entry.value),
    );
  }
  if (value is YamlList) {
    return value.any(_inheritsAllSecrets);
  }
  return false;
}

bool _hasWritePermission(Object? permissions) =>
    permissions is YamlMap &&
    permissions.values.any((Object? access) => access == 'write');

bool _containsPublishOperation(YamlMap job) {
  final Object? stepsValue = job['steps'];
  if (stepsValue is! YamlList) {
    return false;
  }
  for (final YamlMap step in stepsValue.whereType<YamlMap>()) {
    final String uses = step['uses']?.toString() ?? '';
    final int separator = uses.indexOf('@');
    final String action = separator < 0 ? uses : uses.substring(0, separator);
    if (_publishingActions.contains(action)) {
      return true;
    }
    final String run = step['run']?.toString() ?? '';
    if (RegExp(
      r'(^|\s)(gh\s+release\s+create|flutter\s+build\s+appbundle)(\s|$)',
    ).hasMatch(run)) {
      return true;
    }
  }
  return false;
}

String? _environmentName(Object? environment) {
  if (environment is String) {
    return environment;
  }
  if (environment is YamlMap) {
    return environment['name']?.toString();
  }
  return null;
}
