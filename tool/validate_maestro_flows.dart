// Validates the Maestro flow files parse as YAML and use a coherent shape.
//
// Maestro itself is not installed on every machine and needs a device to run a
// flow, so this is the cheapest gate that still catches the errors that
// actually happen when editing these files: broken indentation, a bad multi
// document split, a flow that forgets its appId, or a runFlow pointing at a
// subflow that does not exist.
//
// Run with: dart run tool/validate_maestro_flows.dart
import 'dart:io';

import 'package:yaml/yaml.dart';

void main() {
  final Directory root = Directory('.maestro');
  if (!root.existsSync()) {
    stderr.writeln('No .maestro directory found.');
    exit(1);
  }

  final List<File> files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.yaml'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('No .yaml flows found under .maestro/.');
    exit(1);
  }

  final List<String> problems = <String>[];

  for (final File file in files) {
    final String relative = file.path.replaceAll(r'\', '/');
    final String source = file.readAsStringSync();

    // Maestro flows are two YAML documents: a header (appId, tags) and the
    // command list. config.yaml is allowed to be header-only.
    final List<YamlDocument> documents;
    try {
      documents = loadYamlDocuments(source);
    } on Object catch (error) {
      problems.add('$relative: does not parse as YAML — $error');
      continue;
    }

    final bool isConfig = relative.endsWith('.maestro/config.yaml');
    if (documents.isEmpty) {
      problems.add('$relative: empty file');
      continue;
    }

    final dynamic header = documents.first.contents;
    if (header is! YamlMap || header['appId'] == null) {
      problems.add('$relative: header document is missing appId');
    }

    if (isConfig) {
      continue;
    }

    if (documents.length < 2) {
      problems.add(
        '$relative: expected a second document holding the command list',
      );
      continue;
    }

    final dynamic commands = documents[1].contents;
    if (commands is! YamlList || commands.isEmpty) {
      problems.add('$relative: command document is not a non-empty list');
      continue;
    }

    // Every runFlow target has to resolve, or the flow fails at run time on a
    // device rather than here.
    for (final dynamic command in commands) {
      for (final String target in _runFlowTargets(command)) {
        final String resolved = File(
          '${file.parent.path}/$target',
        ).absolute.path;
        if (!File(resolved).existsSync()) {
          problems.add('$relative: runFlow target not found — $target');
        }
      }
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('Maestro flow validation failed:\n');
    for (final String problem in problems) {
      stderr.writeln('  - $problem');
    }
    exit(1);
  }

  stdout.writeln('Validated ${files.length} Maestro files. No issues found.');
}

/// Collects runFlow file references, including nested ones inside `commands:`.
Iterable<String> _runFlowTargets(dynamic command) sync* {
  if (command is! YamlMap) {
    return;
  }
  final dynamic runFlow = command['runFlow'];
  if (runFlow is String) {
    yield runFlow;
  } else if (runFlow is YamlMap) {
    final dynamic file = runFlow['file'];
    if (file is String) {
      yield file;
    }
    final dynamic nested = runFlow['commands'];
    if (nested is YamlList) {
      for (final dynamic inner in nested) {
        yield* _runFlowTargets(inner);
      }
    }
  }
}
