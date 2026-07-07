import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-engine code only imports approved SI public surface', () {
    final Directory libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    const Set<String> allowedImports = <String>{
      'package:fantastic_guacamole/engine/si/api.dart',
      'package:fantastic_guacamole/engine/si/ai_personality.dart',
      'package:fantastic_guacamole/engine/si/ai_response.dart',
      'package:fantastic_guacamole/engine/si/core/si_core.dart',
      'package:fantastic_guacamole/engine/si/models/si_state.dart',
      'package:fantastic_guacamole/engine/si/offline/behavior_shaping_engine.dart',
      'package:fantastic_guacamole/engine/si/offline/identity_engine.dart',
      'package:fantastic_guacamole/engine/si/offline/narrative_engine.dart',
      'package:fantastic_guacamole/engine/si/offline/user_growth_engine.dart',
      'package:fantastic_guacamole/engine/si/prediction.dart',
      'package:fantastic_guacamole/engine/si/si_ai_service.dart',
      'package:fantastic_guacamole/engine/si/si_decision.dart',
      'package:fantastic_guacamole/engine/si/si_engine_service.dart',
      'package:fantastic_guacamole/engine/si/si_response_policy.dart',
      'package:fantastic_guacamole/engine/si/si_synthetic_soul_layer.dart',
      'package:fantastic_guacamole/engine/si/si_task_core.dart',
      'package:fantastic_guacamole/engine/si/synthetic_intelligence_engine.dart',
    };

    final RegExp importPattern = RegExp("package:fantastic_guacamole/engine/si/[^'\\\"]+");
    final List<String> violations = <String>[];

    for (final FileSystemEntity entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final String normalized = entity.path.replaceAll('\\', '/');
      if (normalized.startsWith('lib/engine/si/')) {
        continue;
      }

      final String contents = entity.readAsStringSync();
      for (final Match match in importPattern.allMatches(contents)) {
        final String importValue = match.group(0)!;
        if (!allowedImports.contains(importValue)) {
          violations.add('$normalized -> $importValue');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Non-engine code must only use the approved SI public surface. Violations:\n${violations.join('\n')}',
    );
  });
}
