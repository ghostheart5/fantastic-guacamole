import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const Set<String> providerRegistrationFiles = <String>{
    'lib/state/providers/domain_usecase_providers.dart',
    'lib/state/providers/domain_usecase_providers.repositories.dart',
    'lib/state/providers/domain_usecase_providers.core.dart',
    'lib/state/providers/domain_usecase_providers.lifecycle.dart',
    'lib/state/providers/domain_usecase_providers.timeline.dart',
    'lib/state/providers/domain_usecase_providers.notes_and_si.dart',
  };
  final RegExp classification = RegExp(
    r'^//[/]? CHRONOSPARK-CLASS: '
    r'(SHIPPING|PLANNED|EXPERIMENTAL|LEGACY|DEPRECATED) '
    r'\| Feature: .+$',
    multiLine: true,
  );

  test('every domain source has a valid classification banner', () {
    final List<File> files =
        Directory('lib/domain')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File file) => file.path.endsWith('.dart'))
            .toList(growable: false)
          ..sort(
            (File first, File second) => first.path.compareTo(second.path),
          );

    final List<String> invalid = <String>[];
    for (final File file in files) {
      final int bannerCount = classification
          .allMatches(file.readAsStringSync())
          .length;
      if (bannerCount != 1) {
        invalid.add('${file.path}: $bannerCount banners');
      }
    }

    expect(invalid, isEmpty, reason: invalid.join('\n'));
  });

  test('domain sources do not depend on engine, state, or Flutter', () {
    final RegExp forbiddenImport = RegExp(
      r"^import 'package:fantastic_guacamole/(engine|state)/|"
      r"^import 'package:flutter/",
      multiLine: true,
    );
    final List<String> violations = <String>[];
    for (final File file in Directory(
      'lib/domain',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final RegExpMatch match in forbiddenImport.allMatches(
        file.readAsStringSync(),
      )) {
        violations.add('${file.path}: ${match.group(0)}');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('domain barrel exports shipping sources only', () {
    final String barrel = File('lib/domain/domain.dart').readAsStringSync();
    final RegExp exportPattern = RegExp(
      r"export '((?:package:fantastic_guacamole/)?[^']+)'",
    );
    final RegExp nonShipping = RegExp(
      r'^//[/]? CHRONOSPARK-CLASS: (PLANNED|EXPERIMENTAL|DEPRECATED) ',
      multiLine: true,
    );
    final List<String> violations = <String>[];

    for (final RegExpMatch match in exportPattern.allMatches(barrel)) {
      final String exported = match.group(1)!;
      final String path = exported.startsWith('package:fantastic_guacamole/')
          ? 'lib/${exported.substring('package:fantastic_guacamole/'.length)}'
          : 'lib/domain/$exported';
      final File target = File(path);
      if (!target.existsSync() ||
          nonShipping.hasMatch(target.readAsStringSync())) {
        violations.add(path);
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('planned sources are quarantined, owned, and removal-bound', () {
    final Map<String, dynamic> manifest =
        jsonDecode(File('tool/planned_source_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 2);
    final Map<String, dynamic> declared =
        manifest['sources'] as Map<String, dynamic>;
    final Map<String, dynamic> decisions =
        manifest['reachabilityDecisions'] as Map<String, dynamic>;
    final RegExp plannedBanner = RegExp(
      r'^//[/]? CHRONOSPARK-CLASS: PLANNED \| Feature: .+$',
      multiLine: true,
    );
    final List<String> actual =
        Directory('lib/domain')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File file) => file.path.endsWith('.dart'))
            .where(
              (File file) => plannedBanner.hasMatch(file.readAsStringSync()),
            )
            .map(_relativePath)
            .toList(growable: false)
          ..sort();
    final List<String> expected = declared.keys.toList(growable: false)..sort();

    expect(actual, expected);
    final Map<String, String> decisionByPath = <String, String>{};
    for (final MapEntry<String, dynamic> decision in decisions.entries) {
      for (final String path
          in (decision.value as List<dynamic>).cast<String>()) {
        expect(
          decisionByPath.containsKey(path),
          isFalse,
          reason: '$path has more than one reachability decision',
        );
        decisionByPath[path] = decision.key;
      }
    }
    expect(decisionByPath.keys.toList()..sort(), expected);
    for (final String path in expected) {
      final Map<String, dynamic> record =
          declared[path] as Map<String, dynamic>;
      expect((record['owner'] as String).trim(), isNotEmpty, reason: path);
      expect(
        (record['removalCriteria'] as String).trim(),
        allOf(isNotEmpty, contains('Remove'), contains('promote')),
        reason: path,
      );
    }

    final Set<String> reachable = _reachableDartSources('lib/main.dart');
    for (final String path in actual) {
      switch (decisionByPath[path]) {
        case 'source-unreachable':
          expect(reachable, isNot(contains(path)), reason: path);
          break;
        case 'compiled-provider-only':
          expect(reachable, contains(path), reason: path);
          final String providerSymbol =
              (declared[path] as Map<String, dynamic>)['providerSymbol']
                  as String;
          expect(providerSymbol.trim(), isNotEmpty, reason: path);
          final List<String> references = _productionReferences(
            providerSymbol,
            excluding: path,
          );
          expect(
            references,
            hasLength(1),
            reason: '$path is no longer provider-registration-only',
          );
          expect(
            providerRegistrationFiles,
            contains(references.single),
            reason: '$path is registered outside its composition library',
          );
          break;
        default:
          fail('$path has an unsupported reachability decision');
      }
    }
  });
}

String _relativePath(File file) => file.absolute.path
    .substring(Directory.current.absolute.path.length + 1)
    .replaceAll('\\', '/');

Set<String> _reachableDartSources(String entrypoint) {
  final String root = Directory.current.absolute.path;
  final String libRoot = Directory('lib').absolute.path;
  final List<File> pending = <File>[File(entrypoint).absolute];
  final Set<String> visited = <String>{};
  final RegExp directive = RegExp(
    r"^\s*(?:import|export|part)\s+'([^']+)'",
    multiLine: true,
  );

  while (pending.isNotEmpty) {
    final File file = pending.removeLast();
    if (!file.existsSync()) continue;
    final String relative = _relativePath(file);
    if (!visited.add(relative)) continue;
    for (final RegExpMatch match in directive.allMatches(
      file.readAsStringSync(),
    )) {
      final String uri = match.group(1)!;
      late final File dependency;
      if (uri.startsWith('package:fantastic_guacamole/')) {
        dependency = File(
          '$libRoot${Platform.pathSeparator}'
          '${uri.substring('package:fantastic_guacamole/'.length)}',
        );
      } else if (!uri.contains(':')) {
        dependency = File.fromUri(file.uri.resolve(uri));
      } else {
        continue;
      }
      final String path = dependency.absolute.path;
      if (path.startsWith(root) && dependency.existsSync()) {
        pending.add(dependency);
      }
    }
  }
  return visited;
}

List<String> _productionReferences(String symbol, {required String excluding}) {
  final List<String> references = <String>[];
  for (final File file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    if (_relativePath(file) == excluding) continue;
    if (file.readAsStringSync().contains(symbol)) {
      references.add(_relativePath(file));
    }
  }
  return references..sort();
}
