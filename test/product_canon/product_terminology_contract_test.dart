import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retired standalone product surfaces stay removed', () {
    for (final String path in <String>[
      'lib/features/personal_alignment',
      'lib/features/plan/ui/plan_screen.dart',
      'lib/state/providers/personal_alignment_provider.dart',
      'lib/state/providers/core_values_provider.dart',
      'lib/state/providers/profile_values_provider.dart',
      'lib/state/providers/insights_provider.dart',
      'lib/state/controllers/insight_controller.dart',
      'lib/data/repositories/insight_repository.dart',
      'lib/engine/insights',
      'lib/ui/system/focus_start_overlay.dart',
    ]) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: 'Retired product path returned: $path',
      );
    }
    expect(
      File('lib/features/signals/ui/signal_screen.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/data/repositories/session_repository.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/domain/entities/session_entity.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/domain/interfaces/i_session_repository.dart').existsSync(),
      isFalse,
    );
    expect(
      File('assets/animations/session_complete.json').existsSync(),
      isFalse,
    );
  });

  test('product UI and tutorial contain none of the forbidden names', () {
    final RegExp forbidden = RegExp(
      r'\b(?:personal[ _-]?alignment|planner[ _-]?analysis|insights?|journals?|focus|sessions?)\b',
      caseSensitive: false,
    );
    final List<String> violations = <String>[];
    for (final String root in <String>[
      'lib/features',
      'lib/app',
      'lib/tutorial',
      'assets',
    ]) {
      final Directory directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final File file
          in directory
              .listSync(recursive: true)
              .whereType<File>()
              .where(_isTextSurface)) {
        final RegExpMatch? match = forbidden.firstMatch(
          file.readAsStringSync(),
        );
        if (match != null) {
          final String normalizedPath = file.path.replaceAll('\\', '/');
          final bool compatibilityRouteTerm =
              normalizedPath.endsWith('lib/app/router/route_paths.dart') &&
              <String>{'insights'}.contains(match.group(0)?.toLowerCase());
          if (compatibilityRouteTerm) {
            continue;
          }
          violations.add('$normalizedPath: ${match.group(0)}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('legacy navigation names resolve into current canon', () {
    expect(appViewFromName('coach'), isNull);
    expect(appViewFromName('smartCoach'), isNull);
    expect(appViewFromName('signal'), isNull);
  });

  test('legacy guidance preference memories retain their category', () {
    final MemoryEntity memory = MemoryEntity.fromJson(<String, dynamic>{
      'id': 'legacy-guidance',
      'text': 'Prefer concise planning guidance.',
      'date': DateTime.utc(2026).toIso8601String(),
      'category': 'coachingPreference',
    });

    expect(memory.category, MemoryCategory.planningGuidancePreference);
  });

  test('active product surfaces contain no retired terminology', () {
    final RegExp retired = RegExp(
      r'\b(?:smart[ _-]?coach|chrono[ _-]?creator|chrono[ _-]?logs|soul[ _-]?maps?|missions?|military|commands?|briefings?|command[ _-]?cent(?:er|re)|control[ _-]?room|tactical|directive|ops|intel|session[ _-]?(?:score|scoring|complete)|last[ _-]?session)\b',
      caseSensitive: false,
    );
    final List<String> violations = <String>[];
    final List<FileSystemEntity> roots = <FileSystemEntity>[
      Directory('lib'),
      Directory('assets'),
      Directory('web'),
      File('index.html'),
      File('testers.html'),
    ];

    for (final FileSystemEntity root in roots) {
      final Iterable<File> files = root is Directory
          ? root
                .listSync(recursive: true)
                .whereType<File>()
                .where(_isTextSurface)
          : <File>[root as File];
      for (final File file in files) {
        final String path = file.path.replaceAll('\\', '/');
        String content = file.readAsStringSync();

        if (path.endsWith('lib/app/router/route_paths.dart') ||
            path.endsWith('lib/app/router/app_router.dart')) {
          content = content
              .replaceAll('legacyCoach', 'legacy_alias')
              .replaceAll('/coach', '/legacy-alias')
              .replaceAll('legacyInsights', 'legacy_alias')
              .replaceAll('/insights', '/legacy-alias')
              .replaceAll('legacySignals', 'legacy_alias')
              .replaceAll('/signals', '/legacy-alias');
        }

        if (path.endsWith('app_flow_controller.dart')) {
          content = content.replaceAll('smartCoach', 'legacy_view');
        }

        final RegExpMatch? match = retired.firstMatch(content);
        if (match != null) {
          violations.add('$path: ${match.group(0)}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

bool _isTextSurface(File file) {
  const Set<String> extensions = <String>{
    '.dart',
    '.html',
    '.json',
    '.md',
    '.txt',
    '.yaml',
    '.yml',
  };
  final String path = file.path.toLowerCase();
  return extensions.any(path.endsWith);
}
