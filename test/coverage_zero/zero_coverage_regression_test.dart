import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _parseZeroCoverageFiles(String lcovContent) {
  final Set<String> zeroFiles = <String>{};

  String? currentFile;
  int found = 0;
  int hit = 0;

  void commit() {
    if (currentFile == null) {
      return;
    }
    if (found > 0 && hit == 0) {
      zeroFiles.add(currentFile);
    }
  }

  for (final String rawLine in lcovContent.split('\n')) {
    final String line = rawLine.trim();
    if (line.startsWith('SF:')) {
      commit();
      currentFile = line.substring(3);
      found = 0;
      hit = 0;
      continue;
    }
    if (line.startsWith('LF:')) {
      found = int.tryParse(line.substring(3)) ?? 0;
      continue;
    }
    if (line.startsWith('LH:')) {
      hit = int.tryParse(line.substring(3)) ?? 0;
      continue;
    }
    if (line == 'end_of_record') {
      commit();
      currentFile = null;
      found = 0;
      hit = 0;
    }
  }

  commit();
  return zeroFiles;
}

void main() {
  group('zero coverage regression', () {
    test('parses zero covered files from lcov records', () {
      const String sample = '''
SF:lib/a.dart
LF:10
LH:0
end_of_record
SF:lib/b.dart
LF:7
LH:3
end_of_record
SF:lib/c.dart
LF:4
LH:0
end_of_record
''';

      final Set<String> zeroFiles = _parseZeroCoverageFiles(sample);

      expect(zeroFiles, <String>{'lib/a.dart', 'lib/c.dart'});
      expect(zeroFiles.contains('lib/b.dart'), isFalse);
    });

    test('all targeted zero-coverage files still exist in lib', () {
      const List<String> targets = <String>[
        'lib/data/storage/hive_boxes.dart',
        'lib/domain/entities/paywall_entity.dart',
        'lib/domain/value_objects/timestamp.dart',
        'lib/engine/learning/learning_history.dart',
        'lib/engine/scoring/session_score.dart',
        'lib/engine/si/si_decision.dart',
        'lib/features/home/ui/models/smart_coach_exchange.dart',
        'lib/features/monetization/domain/paywall_content.dart',
        'lib/state/models/creator_form_data.dart',
        'lib/state/models/profile_view_state.dart',
        'lib/state/models/streak.dart',
        'lib/state/services/si_engine_dependencies.dart',
        'lib/data/di/services_providers.dart',
        'lib/domain/usecases/add_timeline_event.dart',
        'lib/domain/usecases/complete_goal.dart',
        'lib/domain/usecases/create_goal.dart',
        'lib/domain/usecases/create_project.dart',
        'lib/domain/usecases/create_routine.dart',
        'lib/domain/usecases/create_subtask.dart',
        'lib/domain/usecases/delete_goal.dart',
      ];

      for (final String target in targets) {
        expect(File(target).existsSync(), isTrue, reason: target);
      }
    });
  });
}
