import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/patterns_screen_harness.dart';
import '../../support/golden_harness.dart';

/// Golden images of Patterns on the plain kit.
///
/// Only Windows masters exist so far. Follow-up: after the first CI run the
/// Linux masters are generated and this file is registered in
/// scripts/golden_assertion_guard.ps1; until then it is skipped off Windows,
/// so the Linux test job does not fail on missing masters.
final bool _noMasters = !Platform.isWindows;

final HabitEntity _walk = patternsHabit('walk', title: 'Walk');
final HabitEntity _gym = patternsHabit(
  'gym',
  title: 'Gym',
  cadence: HabitCadence.weekly,
);

Future<void> _pumpGolden(
  WidgetTester tester, {
  required double width,
  Locale locale = const Locale('en'),
}) async {
  await pumpPatterns(
    tester,
    locale: locale,
    size: Size(width, 3400),
    habits: <HabitEntity>[_walk, _gym],
    occurrences: <HabitOccurrenceEntity>[
      for (int day = 0; day < 7; day++) habitCheckIn(_walk, patternsAt(day)),
      habitCheckIn(_gym, patternsAt(0)),
    ],
    tasks: <TaskEntity>[
      finishedTask('m1', patternsAt(1)),
      finishedTask('m2', patternsAt(8)),
      finishedTask('m3', patternsAt(15)),
      finishedTask('t', patternsAt(0, 8)),
      finishedTask('w', patternsAt(6)),
      skippedTask('s', patternsAt(2), title: 'Call the bank'),
      openTask('o', title: 'Pay rent', dueDate: patternsAt(3)),
      openTask(
        'p',
        title: 'Write report',
        scheduledFor: patternsAt(0, 14),
        minutes: 90,
      ),
    ],
  );
  await tester.pump();
}

void main() {
  setUpAll(loadAppFontsForGolden);

  testWidgets('matches the compact_320 baseline (English)', skip: _noMasters, (
    tester,
  ) async {
    await _pumpGolden(tester, width: 320);
    await expectLater(
      find.byType(ProgressionScreen),
      matchesGoldenFile(platformGoldenFile('patterns_compact_320.png')),
    );
  });

  testWidgets('matches the regular_500 baseline (English)', skip: _noMasters, (
    tester,
  ) async {
    await _pumpGolden(tester, width: 500);
    await expectLater(
      find.byType(ProgressionScreen),
      matchesGoldenFile(platformGoldenFile('patterns_regular_500.png')),
    );
  });

  testWidgets('matches the compact_320 baseline (Spanish)', skip: _noMasters, (
    tester,
  ) async {
    await _pumpGolden(tester, width: 320, locale: const Locale('es'));
    await expectLater(
      find.byType(ProgressionScreen),
      matchesGoldenFile(platformGoldenFile('patterns_compact_320_es.png')),
    );
  });
}
