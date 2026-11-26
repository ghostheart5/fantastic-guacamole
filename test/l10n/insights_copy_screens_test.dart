import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the Today card, both screens and the Profile button read InsightsCopy',
    () {
      for (final String path in <String>[
        'lib/features/home/ui/today_screen.dart',
        'lib/features/trajectory_engine/ui/trajectory_engine_screen.dart',
        'lib/features/progression/ui/progression_screen.dart',
        'lib/features/profile/ui/profile_screen.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('InsightsCopy'),
          reason: '$path must read its names from InsightsCopy',
        );
      }
    },
  );
}
