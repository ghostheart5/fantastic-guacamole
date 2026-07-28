import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  List<File> dartFilesUnder(String path) {
    final root = Directory(path);
    if (!root.existsSync()) return <File>[];

    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  String readAllLib() {
    final buffer = StringBuffer();

    for (final file in dartFilesUnder('lib')) {
      buffer.writeln(file.path);
      buffer.writeln(file.readAsStringSync());
    }

    return buffer.toString();
  }

  group('ChronoSpark real feature behavior coverage map', () {
    test('core features have at least one provider controller service repository or widget', () {
      final featureTerms = <String, List<String>>{
        'nexus': ['Nexus', 'nexus'],
        'creator': ['Creator', 'creator'],
        'coach': ['Coach', 'SmartCoach', 'coach', 'smart_coach'],
        'timeline': ['Timeline', 'timeline'],
        'profile': ['Profile', 'profile'],
        'progression': ['Progression', 'progression'],
        'trajectory': ['Trajectory', 'trajectory'],
        'si_console': ['SIConsole', 'SI Console', 'si_console'],
        'tutorial': ['Tutorial', 'tutorial'],
        'action_hub': [
          'ActionHub',
          'Action Hub',
          'action_hub',
          'NavigationShell',
          '_showNavigationMap',
        ],
      };

      final lib = readAllLib();
      final missing = <String>[];

      featureTerms.forEach((feature, terms) {
        final exists = terms.any(lib.contains);

        if (!exists) {
          missing.add(feature);
        }
      });

      expect(
        missing,
        isEmpty,
        reason: 'Core feature terms missing from lib source: $missing',
      );
    });

    test('core features have matching tests beyond base smoke coverage', () {
      final expectedTestTerms = <String>[
        'action_hub',
        'auth',
        'creator',
        'daily_plan',
        'navigation',
        'nexus',
        'profile',
        'progression',
        'scheduler',
        'settings',
        'si_console',
        'storage',
        'sync',
        'tasks',
        'timeline',
        'trajectory_engine',
        'tutorial',
        'ui',
      ];

      final dartTestFiles = dartFilesUnder('test')
          .map((file) => file.path.replaceAll('\\', '/').toLowerCase())
          .toList();

      final missing = <String>[];

      for (final term in expectedTestTerms) {
        final hasTest = dartTestFiles.any((path) => path.contains(term));
        if (!hasTest) missing.add(term);
      }

      expect(
        missing,
        isEmpty,
        reason: 'Missing Dart tests for feature terms: $missing',
      );
    });
  });
}
