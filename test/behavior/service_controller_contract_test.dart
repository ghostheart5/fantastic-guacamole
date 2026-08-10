import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  bool isBehaviorServiceFile(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    if (!normalized.endsWith('.dart')) return false;
    if (normalized.endsWith('.g.dart') ||
        normalized.endsWith('.freezed.dart')) {
      return false;
    }
    if (normalized.contains('/test/')) return false;

    final bool inServiceLayer = normalized.contains('/services/');
    final bool namedService = normalized.endsWith('_service.dart');
    final bool isContainerOnly =
        normalized.endsWith('_dependencies.dart') ||
        normalized.endsWith('_events.dart') ||
        normalized.endsWith('/services.dart') ||
        normalized.contains('/di/') ||
        normalized.endsWith('providers.dart');
    return (inServiceLayer || namedService) && !isContainerOnly;
  }

  List<File> dartFilesUnder(String path) {
    final root = Directory(path);
    if (!root.existsSync()) return <File>[];

    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  group('Service and controller contracts', () {
    test(
      'service files expose behavior methods and are not empty wrappers',
      () {
        final emptyServices = <String>[];

        final methodPattern = RegExp(
          r'\b[a-zA-Z_]\w*\s*\([^;{}]*\)\s*(?:async\s*)?(?:=>|\{|;)',
        );

        for (final file in dartFilesUnder('lib')) {
          if (!isBehaviorServiceFile(file.path)) continue;

          final text = file.readAsStringSync();
          final methodCount = methodPattern.allMatches(text).length;
          final getterCount = RegExp(
            r'\bget\s+[a-zA-Z_]\w*\s*=>',
          ).allMatches(text).length;

          if (methodCount + getterCount < 1) {
            emptyServices.add(file.path);
          }
        }

        expect(
          emptyServices,
          isEmpty,
          reason:
              'Service files with no obvious behavior methods: $emptyServices',
        );
      },
    );

    test('controller files expose action methods and state intent', () {
      final suspicious = <String>[];

      final actionWords = <String>[
        'load',
        'save',
        'start',
        'stop',
        'reset',
        'create',
        'update',
        'delete',
        'toggle',
        'select',
        'submit',
        'sign',
        'restore',
        'refresh',
        'mark',
        'skip',
        'complete',
        'detect',
        'query',
        'tonexus',
        'tocreator',
        'totimeline',
        'toprofile',
        'toprogression',
        'toconsole',
        'tosmartcoach',
        'totrajectoryengine',
      ];

      for (final file in dartFilesUnder('lib')) {
        final normalized = file.path.replaceAll('\\', '/').toLowerCase();
        if (!normalized.contains('controller')) continue;
        if (normalized.endsWith('.g.dart') ||
            normalized.endsWith('.freezed.dart') ||
            normalized.endsWith('.providers.dart')) {
          continue;
        }

        final text = file.readAsStringSync().toLowerCase();
        final hasAction = actionWords.any(text.contains);

        if (!hasAction) {
          suspicious.add(file.path);
        }
      }

      expect(
        suspicious,
        isEmpty,
        reason:
            'Controller files without obvious action/state behavior: $suspicious',
      );
    });

    test(
      'providers do not create duplicate global instances of the same controller class',
      () {
        final providerFiles = dartFilesUnder('lib')
            .where((file) => file.path.toLowerCase().contains('provider'))
            .toList();

        final creations = <String, List<String>>{};
        final creationPattern = RegExp(
          r'=\s*(?:Provider|ChangeNotifierProvider|StateNotifierProvider|NotifierProvider|AsyncNotifierProvider)<[^>]+>\([^)]*=>\s*([A-Z]\w+)\(',
        );

        for (final file in providerFiles) {
          final text = file.readAsStringSync();

          for (final match in creationPattern.allMatches(text)) {
            final className = match.group(1)!;
            creations.putIfAbsent(className, () => <String>[]).add(file.path);
          }
        }

        final duplicates = creations.entries
            .where((entry) => entry.value.length > 1)
            .map((entry) => '${entry.key}: ${entry.value}')
            .toList();

        expect(
          duplicates,
          isEmpty,
          reason:
              'Possible duplicate provider-created controller/service instances: $duplicates',
        );
      },
    );
  });
}
