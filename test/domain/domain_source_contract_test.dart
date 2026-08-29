import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
      if (bannerCount == 0) {
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
}
