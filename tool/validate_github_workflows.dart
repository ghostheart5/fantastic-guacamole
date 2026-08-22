import 'dart:io';

import 'package:yaml/yaml.dart';

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
    final String relativePath = file.path.replaceAll('\\', '/');
    final String source = file.readAsStringSync();
    Object? document;
    try {
      document = loadYaml(source);
    } on YamlException catch (error) {
      failures.add('$relativePath is invalid YAML: ${error.message}');
      continue;
    }

    if (document is! YamlMap) {
      failures.add('$relativePath must contain a YAML mapping.');
      continue;
    }
    if (!document.containsKey('on')) {
      failures.add('$relativePath must declare explicit triggers.');
    }
    if (!document.containsKey('permissions')) {
      failures.add('$relativePath must declare top-level permissions.');
    }
    if (source.contains('ubuntu-latest')) {
      failures.add('$relativePath uses the mutable ubuntu-latest runner.');
    }
    if (source.contains(':latest')) {
      failures.add('$relativePath uses a mutable latest tag.');
    }
    if (source.contains('secrets: inherit')) {
      failures.add('$relativePath inherits all caller secrets.');
    }

    final Object? jobsValue = document['jobs'];
    if (jobsValue is! YamlMap || jobsValue.isEmpty) {
      failures.add('$relativePath must declare at least one job.');
      continue;
    }

    for (final MapEntry<Object?, Object?> jobEntry in jobsValue.entries) {
      final String jobName = jobEntry.key.toString();
      final Object? jobValue = jobEntry.value;
      if (jobValue is! YamlMap) {
        failures.add('$relativePath job $jobName must be a mapping.');
        continue;
      }

      _validateUses(
        file: relativePath,
        location: 'job $jobName',
        uses: jobValue['uses'],
        configuration: jobValue,
        failures: failures,
      );

      final Object? runsOn = jobValue['runs-on'];
      if (runsOn != null && !jobValue.containsKey('timeout-minutes')) {
        failures.add('$relativePath job $jobName must set timeout-minutes.');
      }
      if (runsOn is String &&
          runsOn.startsWith('ubuntu-') &&
          runsOn != 'ubuntu-24.04') {
        failures.add(
          '$relativePath job $jobName must pin the hosted runner to ubuntu-24.04.',
        );
      }

      final Object? stepsValue = jobValue['steps'];
      if (stepsValue == null) {
        continue;
      }
      if (stepsValue is! YamlList) {
        failures.add('$relativePath job $jobName steps must be a list.');
        continue;
      }
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
      }
    }
  }

  _validateReleaseControls(failures);

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
  final Match? action = RegExp(r'^([^@\s]+)@([0-9a-f]{40})$').firstMatch(uses);
  if (action == null) {
    failures.add('$file $location must pin external action "$uses" to a SHA.');
    return;
  }
  if (action.group(1) != 'actions/checkout') {
    return;
  }
  final Object? withValue = configuration['with'];
  final Object? persistCredentials = withValue is YamlMap
      ? withValue['persist-credentials']
      : null;
  if (persistCredentials != false) {
    failures.add(
      '$file $location must set checkout persist-credentials to false.',
    );
  }
}

void _validateReleaseControls(List<String> failures) {
  final String android = File(
    '.github/workflows/android-release.yml',
  ).readAsStringSync();
  if (!android.contains('workflow_dispatch:')) {
    failures.add('Android release must support a manual build-only preflight.');
  }
  if (!android.contains(
    "if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')",
  )) {
    failures.add('Android manual preflight must not publish a GitHub release.');
  }
  if (!android.contains('environment: production')) {
    failures.add('Android signing must use the production environment.');
  }
  if (!android.contains(r'chronospark-release-${{ github.run_id }}')) {
    failures.add('Android artifacts must use a run-scoped name.');
  }

  final String backend = File(
    '.github/workflows/backend-reconciliation.yml',
  ).readAsStringSync();
  if (!backend.contains('--output /dev/null') ||
      backend.contains('--fail-with-body')) {
    failures.add('Backend reconciliation must not print response bodies.');
  }
}
