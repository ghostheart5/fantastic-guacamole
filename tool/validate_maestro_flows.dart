// Validates the Maestro flow files parse as YAML and use a coherent shape.
//
// Maestro itself is not installed on every machine and needs a device to run a
// flow, so this is the cheapest gate that still catches the errors that
// actually happen when editing these files: broken indentation, a bad multi
// document split, a flow that forgets its appId, or a runFlow pointing at a
// subflow that does not exist.
//
// It also checks that the text a flow waits for or taps is still a string
// literal in lib/. Limits: this proves the string exists somewhere in the app,
// not that the screen the flow is on renders it (a label such as "Sign in" is
// also used elsewhere). Text built from several literals, or by adjacent
// literal concatenation, has to be listed in composedLabels with its builder.
// Spanish copy and `id:` selectors are not checked.
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
  final AppText appText = AppText.load(Directory('lib'));
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
      appText,
      typedText: typedText,
    )) {
      problems.add('$relative: asserts text not found in lib/ — "$stale"');
    }
  }

  for (final String label in staleComposedLabels(appText)) {
    problems.add(
      'composedLabels: the code that builds "$label" is no longer in lib/',
    );
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

/// The text of lib/: [pieces] are the contents of its Dart string literals
/// (comments are skipped, interpolations split a literal in two, escapes are
/// undone, case and whitespace are normalized) and [raw] is the lower-cased
/// source, used only to confirm that an allowlisted builder still exists.
class AppText {
  AppText(Iterable<String> sources)
    : raw = sources.join('\n').toLowerCase(),
      pieces = <String>{for (final String s in sources) ...literalPieces(s)};

  factory AppText.load(Directory libDir) => AppText(<String>[
    for (final FileSystemEntity e in libDir.listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart')) e.readAsStringSync(),
  ]);

  final String raw;
  final Set<String> pieces;
}

// Comments first, so a quote inside a comment never opens a string. Groups:
// 1 and 2 triple-quoted, 3 and 4 single-line. `${...}` is consumed whole so a
// quote inside an interpolation does not end the literal.
final RegExp _dartToken = RegExp(
  r'//[^\n]*|/\*[\s\S]*?\*/|'
  r"'''([\s\S]*?)'''|"
  r'"""([\s\S]*?)"""|'
  r"'((?:[^'\\\n$]|\\.|\$\{[^}]*\}|\$)*)'|"
  r'"((?:[^"\\\n$]|\\.|\$\{[^}]*\}|\$)*)"',
);
final RegExp _interpolation = RegExp(
  r'(?<!\\)\$\{[^}]*\}|(?<!\\)\$[A-Za-z_]\w*',
);

/// The normalized contents of every string literal in Dart [source].
Iterable<String> literalPieces(String source) sync* {
  for (final RegExpMatch m in _dartToken.allMatches(source)) {
    final String? content =
        m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4);
    if (content == null) {
      continue;
    }
    for (final String part in content.split(_interpolation)) {
      final String piece = normalizeText(_unescape(part));
      if (piece.isNotEmpty) {
        yield piece;
      }
    }
  }
}

String _unescape(String text) => text.replaceAllMapped(
  RegExp(r'\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|.)', dotAll: true),
  (Match m) {
    final String code = m[1]!;
    if (code.startsWith('u')) {
      final String hex = code.replaceAll(RegExp(r'[u{}]'), '');
      return String.fromCharCode(int.parse(hex, radix: 16));
    }
    return code == 'n' || code == 't' ? ' ' : code;
  },
);

/// Lower-cases, folds typographic apostrophes, collapses whitespace and drops
/// trailing full stops, so two spellings of the same label compare equal.
String normalizeText(String text) => text
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[.:]+$'), '')
    .trim();

/// Returns the selectors' phrases, in the flow command list [commands], that
/// are visible-text selectors the app does not render.
///
/// Each selector is expanded into the phrases it can match (`(?:a|b)` gives
/// two, `.*` and newlines split a phrase into parts). A phrase with no
/// wildcard must equal one whole string literal in lib/; the parts of a
/// phrase with wildcards must each sit inside one string literal. Selectors
/// that use `id:` and `${...}` variables are not text and are skipped.
List<String> staleTextFragments(
  dynamic commands,
  AppText app, {
  Set<String> typedText = const <String>{},
}) {
  final Set<String> typed = <String>{
    for (final String t in typedText) ...<String>[
      normalizeText(t),
      ...t.split(RegExp(r'\.\s|\n')).map(normalizeText),
    ],
  }..removeWhere((String t) => t.length < 3);
  final Set<String> stale = <String>{};
  for (final String selector in _textSelectors(commands)) {
    for (final String alternative in _expandSelector(selector)) {
      String text = alternative.toLowerCase().replaceAll('’', "'");
      for (final String t in typed) {
        text = text.replaceAll(t, _wild);
      }
      text = text
          .replaceAll('\n', _wild)
          .replaceAll('. ', '.$_wild')
          .replaceAll(': ', ':$_wild');
      final List<String> parts = text
          .split(_wild)
          .map(normalizeText)
          .where((String p) => p.length >= 4)
          .toList();
      final bool whole = !text.contains(_wild);
      for (final String part in parts) {
        final bool found =
            platformLabels.contains(part) ||
            composedLabels.keys.any(part.contains) ||
            (whole
                ? app.pieces.contains(part)
                : app.pieces.any((String p) => p.contains(part)));
        if (!found) {
          stale.add(whole ? alternative : part);
        }
      }
    }
  }
  return stale.toList()..sort();
}

/// Allowlist entries whose builder text is no longer anywhere in lib/.
List<String> staleComposedLabels(AppText app) => <String>[
  for (final MapEntry<String, String> e in composedLabels.entries)
    if (!app.raw.contains(e.value)) e.key,
]..sort();

const String _wild = '\u0000';

/// Expands the regular expression [selector] into the phrases it can match.
/// Unknown constructs become a wildcard. A trailing `?` after a plain
/// character is kept as text ("Forgot Password?").
List<String> _expandSelector(String selector) => _Expander(
  selector.replaceAll(RegExp(r'\$\{[^}]*\}'), _wild),
).alternatives();

class _Expander {
  _Expander(this.source);

  final String source;
  int i = 0;

  List<String> alternatives() {
    final List<String> out = sequence();
    while (i < source.length && source[i] == '|') {
      i++;
      out.addAll(sequence());
    }
    return out;
  }

  List<String> sequence() {
    List<String> acc = <String>[''];
    while (i < source.length && source[i] != '|' && source[i] != ')') {
      final String c = source[i];
      List<String> item;
      bool literal = false;
      if (c == '(') {
        i++;
        if (source.startsWith('?:', i)) {
          i += 2;
          item = alternatives();
        } else if (source.startsWith('?', i)) {
          i = source.indexOf(')', i) + 1; // flag group such as (?s)
          continue;
        } else {
          item = alternatives();
        }
        i++; // the closing parenthesis
      } else if (c == '[') {
        while (i < source.length && source[i] != ']') {
          i += source[i] == r'\' ? 2 : 1;
        }
        i++;
        item = <String>[_wild];
      } else if (c == r'\') {
        final String n = i + 1 < source.length ? source[i + 1] : '';
        i += 2;
        item = <String>[
          switch (n) {
            's' => ' ',
            'n' => '\n',
            'd' || 'w' || 'S' => _wild,
            _ => n,
          },
        ];
      } else if (c == '^' || c == r'$') {
        i++;
        item = <String>[''];
      } else if (c == '.') {
        i++;
        item = <String>[_wild];
      } else {
        i++;
        item = <String>[c];
        literal = true;
      }
      if (i < source.length) {
        final String q = source[i];
        if ((q == '?' && literal && i == source.length - 1) == false &&
            (q == '?' || q == '*')) {
          i++;
          // An optional group is dropped, so only its fixed skeleton is
          // checked; an optional single character is kept.
          if (!literal && !(item.length == 1 && item.first == _wild)) {
            item = <String>[''];
          }
        } else if (q == '+') {
          i++;
        } else if (q == '{') {
          i = source.indexOf('}', i) + 1;
        }
        if (i < source.length && source[i] == '?' && q != '?') {
          i++; // lazy quantifier
        }
      }
      acc = <String>[
        for (final String a in acc)
          for (final String b in item) '$a$b',
      ].take(256).toList();
    }
    return acc;
  }
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

/// Buttons drawn by Android itself (keyboard action, date dialog), not by lib/.
const Set<String> platformLabels = <String>{'enter'};

/// Labels the app assembles at run time, so the full text is not a string
/// literal in lib/. Each entry maps the phrase a flow uses to a lower-cased
/// piece of the code that builds it; the check fails if that code disappears.
const Map<String, String> composedLabels = <String, String>{
  // lib/l10n/creator_copy.dart: 'Save ${kind(name).toLowerCase()}'.
  'save goal': r"'save ${kind(name).tolowercase()}'",
  'save habit': r"'save ${kind(name).tolowercase()}'",
  'save task': r"'save ${kind(name).tolowercase()}'",
  // lib/l10n/creator_copy.dart: '$count time(s) per $period'.
  '1 time per day': r"'time' : 'times'} per $period",
  // lib/features/creator/ui/daily_rhythms_screen.dart: 'Completed this $period'.
  'completed this day': r"${es ? 'en este' : 'this'} $period",
  // lib/features/creator/ui/daily_rhythms_screen.dart: 'Skip this $period'.
  'skip this day': r"'skip this $period'",
  // lib/l10n/creator_copy.dart changeCount: '$count change(s) saved.'.
  '1 change saved': r"'change' : 'changes'} ${undone ? 'undone' : 'saved'}",
  // lib/state/providers/task_provider.dart surface 'task_lifecycle', title
  // cased by _learningLabel in settings_screen.planning_sections.dart.
  'task lifecycle': "surface: 'task_lifecycle'",
  // lib/domain/usecases/apply_learning_feedback.dart: 'the ${kind.name} outcome'.
  'completed outcome': r'the ${kind.name} outcome',
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
