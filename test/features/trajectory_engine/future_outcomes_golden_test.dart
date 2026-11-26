import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/future_outcomes_harness.dart';
import '../../support/golden_harness.dart';

/// Golden images of Future outcomes on the plain kit (Windows masters; the
/// Linux masters are generated separately).
void main() {
  setUpAll(loadAppFontsForGolden);

  Future<void> pumpGolden(
    WidgetTester tester, {
    required double width,
    Locale locale = const Locale('en'),
  }) async {
    await pumpFutureOutcomes(
      tester,
      locale: locale,
      theme: appTheme,
      size: Size(width, 1800),
    );
  }

  testWidgets('matches the compact_320 baseline (English)', (tester) async {
    await pumpGolden(tester, width: 320);
    await expectLater(
      find.byType(TrajectoryEngineScreen),
      matchesGoldenFile(platformGoldenFile('future_outcomes_compact_320.png')),
    );
  });

  testWidgets('matches the regular_500 baseline (English)', (tester) async {
    await pumpGolden(tester, width: 500);
    await expectLater(
      find.byType(TrajectoryEngineScreen),
      matchesGoldenFile(platformGoldenFile('future_outcomes_regular_500.png')),
    );
  });

  testWidgets('matches the compact_320 baseline (Spanish)', (tester) async {
    await pumpGolden(tester, width: 320, locale: const Locale('es'));
    await expectLater(
      find.byType(TrajectoryEngineScreen),
      matchesGoldenFile(
        platformGoldenFile('future_outcomes_compact_320_es.png'),
      ),
    );
  });
}
