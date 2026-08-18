import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retired standalone product surfaces stay removed', () {
    expect(
      File('lib/features/insights/ui/insight_screen.dart').existsSync(),
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

  test('legacy navigation names resolve into current canon', () {
    expect(appViewFromName('coach'), isNull);
    expect(appViewFromName('smartCoach'), isNull);
    expect(appViewFromName('insight'), isNull);
  });

  test('legacy tutorial step progress migrates to Smart Planner', () {
    final TutorialProgress progress = TutorialProgress.fromJson(
      <String, Object?>{
        'completed': <String>['coach_quick_prompt'],
      },
    );

    expect(progress.completedStepIds, contains('smart_planner_quick_prompt'));
    expect(progress.completedStepIds, isNot(contains('coach_quick_prompt')));
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
      r'\b(?:smart[ _-]?coach|chrono[ _-]?creator|chrono[ _-]?logs|soul[ _-]?maps?|mission|command[ _-]?cent(?:er|re)|control[ _-]?room|tactical|directive|ops|intel|session[ _-]?(?:score|scoring|complete)|last[ _-]?session)\b',
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

        // Persisted profile key and historical Timeline event discriminator
        // remain readable so existing users do not lose saved state.
        if (path.endsWith('personal_alignment_provider.dart')) {
          content = content.replaceAll('soul_map_profile_v1', 'legacy_key');
        }
        if (path.endsWith('logs_screen.dart')) {
          content = content.replaceAll("case 'mission':", "case 'legacy':");
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
