import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const int responsibilityFileLimit = 1600;
  const Map<String, List<String>> splitLibraries = <String, List<String>>{
    'lib/features/settings/ui/settings_screen.dart': <String>[
      'settings_screen.sections.dart',
      'settings_screen.planning_sections.dart',
      'settings_screen.person_context.dart',
      'settings_screen.governance_sections.dart',
      'settings_screen.data_sections.dart',
      'settings_screen.widgets.dart',
    ],
    'lib/features/si_console/ui/si_console_screen.dart': <String>[
      'si_console_screen.widgets.dart',
    ],
    'lib/state/controllers/smart_planner_query_controller.dart': <String>[
      'smart_planner_query_controller.support.dart',
    ],
    'lib/features/timeline/ui/timeline_screen.dart': <String>[
      'timeline_screen.widgets.dart',
    ],
  };

  test('Priority 7 libraries retain explicit responsibility boundaries', () {
    final List<String> violations = <String>[];

    for (final MapEntry<String, List<String>> library
        in splitLibraries.entries) {
      final File coordinator = File(library.key);
      final String coordinatorSource = coordinator.readAsStringSync();
      _checkSize(coordinator, responsibilityFileLimit, violations);

      for (final String partName in library.value) {
        if (!coordinatorSource.contains("part '$partName';")) {
          violations.add(
            '${library.key}: missing part directive for $partName',
          );
        }
        final File part = File('${coordinator.parent.path}/$partName');
        if (!part.existsSync()) {
          violations.add('${part.path}: responsibility part is missing');
          continue;
        }
        _checkSize(part, responsibilityFileLimit, violations);
        final String expectedPartOf =
            "part of '${coordinator.uri.pathSegments.last}';";
        if (!part.readAsStringSync().contains(expectedPartOf)) {
          violations.add('${part.path}: missing $expectedPartOf');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

void _checkSize(File file, int maximum, List<String> violations) {
  final int lines = file.readAsLinesSync().length;
  if (lines > maximum) {
    violations.add(
      '${file.path}: $lines lines exceeds the $maximum-line limit',
    );
  }
}
