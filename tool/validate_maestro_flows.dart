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
  final String appCorpus = loadAppTextCorpus(Directory('lib'));
  final Set<String> typedText = <String>{};
  for (final File file in files) {
    try {
      for (final YamlDocument document in loadYamlDocuments(
        file.readAsStringSync(),
      )) {
        typedText.addAll(inputTexts(document.contents));
      }
    } on Object {
      // Reported with the parse problem below.
    }
  }

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

    // Text the flow waits for or taps has to still exist in the app.
    for (final String stale in staleTextFragments(
      commands,
      appCorpus,
      typedText: typedText,
    )) {
      problems.add('$relative: asserts text not found in lib/ — "$stale"');
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

/// Lower-cased text of every Dart file under [libDir], with string escapes
/// undone and whitespace collapsed, so literals can be searched for.
String loadAppTextCorpus(Directory libDir) {
  final StringBuffer buffer = StringBuffer();
  for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      buffer.writeln(entity.readAsStringSync());
    }
  }
  return _normalizeText(
    buffer.toString().replaceAll(r"'", "'").replaceAll(r'\"', '"'),
  );
}

String _normalizeText(String text) =>
    text.replaceAll('’', "'").replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Returns the literal fragments, in the flow command list [commands], that
/// are visible-text selectors but do not appear anywhere in [corpus].
///
/// Selectors are regular expressions in Maestro, so each one is split on regex
/// syntax and every remaining run of at least four characters is checked.
/// Selectors that use `id:` and `${...}` variables are not text and are skipped.
List<String> staleTextFragments(
  dynamic commands,
  String corpus, {
  Set<String> typedText = const <String>{},
}) {
  final Set<String> stale = <String>{};
  for (final String selector in _textSelectors(commands)) {
    for (final String fragment in _literalFragments(selector)) {
      // Text the flows type themselves (task titles, sentinels) is data, not
      // app copy: remove it and check what is left.
      String rest = _normalizeText(fragment);
      for (final String typed in typedText) {
        for (final String part in _literalFragments(typed)) {
          rest = rest.replaceAll(_normalizeText(part), '|');
        }
      }
      for (final String piece in rest.split('|')) {
        final String text = piece.trim();
        if (text.length >= 4 &&
            !composedLabels.contains(text) &&
            !corpus.contains(text)) {
          stale.add(fragment);
        }
      }
    }
  }
  return stale.toList()..sort();
}

/// Every `inputText` and `env:` value in [node], however deeply nested. These
/// are data the flows type or pass around, not copy the app has to contain.
Iterable<String> inputTexts(dynamic node) sync* {
  if (node is YamlList) {
    for (final dynamic item in node) {
      yield* inputTexts(item);
    }
  } else if (node is YamlMap) {
    for (final MapEntry<dynamic, dynamic> entry in node.entries) {
      final dynamic value = entry.value;
      if (entry.key == 'inputText' && value is String) {
        yield value;
      } else if (entry.key == 'env' && value is YamlMap) {
        yield* value.values.whereType<String>();
      } else {
        yield* inputTexts(value);
      }
    }
  }
}

Iterable<String> _literalFragments(String selector) sync* {
  final String stripped = selector
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '|')
      .replaceAll(RegExp(r'\(\?[a-z:]*\)?'), '|')
      .replaceAll(r'\.', '\u0001')
      .replaceAll(RegExp(r'\\[a-zA-Z"]'), '|')
      .replaceAll(RegExp(r'\.[*+?]?'), '|')
      .replaceAll(RegExp(r'[\^$()\[\]{}|*+?\\]'), '|')
      .replaceAll('\u0001', '.');
  // Accessibility labels join several strings with newlines, full stops or
  // colons, and the app builds them from separate literals.
  final RegExp boundary = RegExp(r'[|\n]|\.\s|\.$|:\s');
  for (final String part in stripped.split(boundary)) {
    final String fragment = part.trim().replaceAll(RegExp(r'\.+$'), '');
    if (fragment.length >= 4) {
      yield fragment;
    }
  }
}

/// Labels the app assembles at run time (for example `Save ${kind}`), so the
/// full text is not a literal in lib/. Each was checked against its builder.
const Set<String> composedLabels = <String>{
  'save goal',
  'save habit',
  'save task',
  '1 time per day',
  'completed this day',
  'skip this day',
  '1 change saved',
  'task lifecycle',
  'completed outcome',
};

/// Only positive selectors (things the flow waits for or taps) are checked.
/// An `assertNotVisible` of retired text passes harmlessly.
const Set<String> _textKeys = <String>{
  'assertVisible',
  'tapOn',
  'longPressOn',
  'extendedWaitUntil',
  'visible',
  'text',
};

Iterable<String> _textSelectors(dynamic node) sync* {
  if (node is YamlList) {
    for (final dynamic item in node) {
      yield* _textSelectors(item);
    }
  } else if (node is YamlMap) {
    for (final MapEntry<dynamic, dynamic> entry in node.entries) {
      final dynamic value = entry.value;
      if (_textKeys.contains(entry.key) && value is String) {
        yield value;
      } else {
        yield* _textSelectors(value);
      }
    }
  }
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
