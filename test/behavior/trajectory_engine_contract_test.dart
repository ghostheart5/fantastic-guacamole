import 'dart:io';

import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Trajectory engine contract', () {
    test('Trajectory engine screen is importable', () {
      const Widget widget = TrajectoryEngineScreen();
      expect(widget, isA<TrajectoryEngineScreen>());
    });

    test('trajectory feature exists with directional/pattern semantics', () {
      final String text = SourceTestUtils.readAllConcatenated('lib/features/trajectory_engine').toLowerCase();
      expect(text.contains('trajectory'), isTrue);
      expect(
        text.contains('pattern') || text.contains('habit') || text.contains('future'),
        isTrue,
      );
    });

    test('trajectory state wiring uses provider/controller boundaries', () {
      final String screen = SourceTestUtils.readText(
        File('lib/features/trajectory_engine/ui/trajectory_engine_screen.dart'),
      ).toLowerCase();

      expect(screen.contains('provider') || screen.contains('controller'), isTrue);
      expect(screen.contains('hive_service') || screen.contains('shared_prefs_service'), isFalse);
    });
  });
}
