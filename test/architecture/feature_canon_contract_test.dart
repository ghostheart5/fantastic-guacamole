import 'dart:io';

import 'package:fantastic_guacamole/app/feature_canon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature canon exposes exactly seven unique active surfaces', () {
    expect(ChronoSparkFeatureCanon.active, hasLength(7));
    expect(
      ChronoSparkFeatureCanon.active.map((item) => item.id).toSet(),
      hasLength(7),
    );
    expect(
      ChronoSparkFeatureCanon.active.map((item) => item.route).toSet(),
      hasLength(7),
    );
  });

  test('canonical surfaces do not expose retired product terminology', () {
    for (final ChronoSparkFeatureDefinition feature
        in ChronoSparkFeatureCanon.active) {
      for (final String prohibited
          in ChronoSparkFeatureCanon.prohibitedStandaloneProductTerms) {
        expect(
          feature.displayName.toLowerCase(),
          isNot(contains(prohibited.toLowerCase())),
          reason: '${feature.displayName} exposed retired term $prohibited.',
        );
      }
    }
  });

  test('Nexus is home and Insight has no canonical feature', () {
    expect(
      ChronoSparkFeatureCanon.definition(ChronoSparkFeatureId.nexus).route,
      '/nexus',
    );
    expect(
      ChronoSparkFeatureCanon.active.any(
        (item) => item.displayName.toLowerCase().contains('insight'),
      ),
      isFalse,
    );
  });

  test('active product surfaces do not revive retired feature labels', () {
    const List<String> roots = <String>[
      'lib/features/nexus',
      'lib/features/home/ui',
      'lib/features/creator',
      'lib/features/si_console',
      'lib/features/timeline',
      'lib/features/trajectory_engine',
      'lib/features/progression',
      'lib/app/navigation_shell.dart',
      'lib/state/controllers/app_flow_controller.dart',
      'lib/l10n',
      'lib/tutorial',
      'assets/tutorials',
    ];
    final RegExp retired = RegExp(
      r'focus session|smart coach|\bcoach\b|flowmap|\bascension\b',
      caseSensitive: false,
    );
    final List<String> violations = <String>[];

    for (final String root in roots) {
      final FileSystemEntity entity = FileSystemEntity.isDirectorySync(root)
          ? Directory(root)
          : File(root);
      final Iterable<File> files = entity is Directory
          ? entity
                .listSync(recursive: true)
                .whereType<File>()
                .where(
                  (File file) =>
                      file.path.endsWith('.dart') ||
                      file.path.endsWith('.arb') ||
                      file.path.endsWith('.json'),
                )
          : <File>[entity as File];
      for (final File file in files) {
        if (retired.hasMatch(file.readAsStringSync())) {
          violations.add(file.path);
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('active SI engine cannot emit removed Focus or Session actions', () {
    final List<File> files = Directory('lib/engine/si')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final String source = files
        .map((File file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('launch_focus_session')));
    expect(source, isNot(contains('start_focus')));
  });
}
