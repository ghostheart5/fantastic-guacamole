import 'dart:ui' as ui;

import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/patterns_screen_harness.dart';

/// Long names in every list on the page.
final HabitEntity _longHabit = patternsHabit(
  'long',
  title: 'Walk around the big park with the dog before breakfast every day',
);
final HabitEntity _weekly = patternsHabit(
  'weekly',
  title: 'Clean the whole kitchen and the fridge',
  cadence: HabitCadence.weekly,
);

final List<TaskEntity> _tasks = <TaskEntity>[
  for (int i = 0; i < 6; i++) finishedTask('f$i', patternsAt(i * 7 % 27, 9)),
  skippedTask(
    's',
    patternsAt(1),
    title: 'Call the insurance company about the renewal of the car policy',
  ),
  openTask(
    'o',
    title: 'Send the signed rental agreement back to the landlord',
    dueDate: patternsAt(2),
  ),
  openTask(
    'w',
    title: 'Prepare the quarterly planning presentation',
    scheduledFor: patternsAt(0, 15),
    minutes: 135,
  ),
  openTask('u', title: 'Sort the holiday photos'),
];

final List<HabitOccurrenceEntity> _checkIns = <HabitOccurrenceEntity>[
  for (int day = 0; day < 4; day++) habitCheckIn(_longHabit, patternsAt(day)),
  habitCheckIn(
    _longHabit,
    patternsAt(5),
    outcome: HabitOccurrenceOutcome.skipped,
  ),
  habitCheckIn(_weekly, patternsAt(8)),
];

Future<void> _pumpFull(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size size = const Size(400, 8000),
  double textScale = 1.0,
}) => pumpPatterns(
  tester,
  tasks: _tasks,
  habits: <HabitEntity>[_longHabit, _weekly],
  occurrences: _checkIns,
  locale: locale,
  theme: theme,
  size: size,
  textScale: textScale,
);

void main() {
  for (final ThemeData theme in <ThemeData>[appTheme, appLightTheme]) {
    for (final String language in const <String>['en', 'es']) {
      for (final int range in const <int>[7, 30]) {
        testWidgets('no overflow at text scale 2.0 on 320 dp ($language, '
            '${theme.brightness.name} theme, $range days)', (tester) async {
          await _pumpFull(
            tester,
            locale: Locale(language),
            theme: theme,
            size: const Size(320, 20000),
            textScale: 2,
          );
          if (range == 30) {
            await tester.tap(
              inPatternsSection(
                'patterns-range',
                find.text(language == 'es' ? '30 días' : '30 days'),
              ),
            );
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          // Every text stays inside the 320 dp page.
          final List<String> outside = <String>[];
          for (final Element element in find.byType(Text).evaluate()) {
            final RenderObject? object = element.renderObject;
            if (object is! RenderBox || !object.hasSize || !object.attached) {
              continue;
            }
            final Rect rect = MatrixUtils.transformRect(
              object.getTransformTo(null),
              Offset.zero & object.size,
            );
            if (rect.left < -0.5 || rect.right > 320.5) {
              outside.add('${(element.widget as Text).data} $rect');
            }
          }
          expect(outside, isEmpty, reason: outside.join(' / '));
        });
      }
    }
  }

  testWidgets('every control is at least 48 by 48', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpFull(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the empty page keeps 48 dp targets too', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpPatterns(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  for (final String language in const <String>['en', 'es']) {
    testWidgets('the range and the switch announce their selected state '
        '($language)', (tester) async {
      final bool es = language == 'es';
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpFull(tester, locale: Locale(language));
      SemanticsData chip(String label) => tester
          .getSemantics(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(ChoiceChip),
            ),
          )
          .getSemanticsData();
      expect(
        chip(es ? '7 días' : '7 days').flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        chip(es ? '30 días' : '30 days').flagsCollection.isSelected,
        ui.Tristate.isFalse,
      );
      SemanticsData segment(String label) => tester
          .getSemantics(
            find
                .descendant(
                  of: find.byKey(InsightsDestinationSwitch.switchKey),
                  matching: find.bySemanticsLabel(label),
                )
                .last,
          )
          .getSemanticsData();
      expect(
        segment(es ? 'Patrones' : 'Patterns').flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        segment(
          es ? 'Resultados futuros' : 'Future outcomes',
        ).flagsCollection.isSelected,
        ui.Tristate.isFalse,
      );
      await tester.tap(find.text(es ? '30 días' : '30 days'));
      await tester.pump();
      expect(
        chip(es ? '30 días' : '30 days').flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      handle.dispose();
    });
  }

  testWidgets('a screen reader reads the trend numbers as text', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpPatterns(
      tester,
      tasks: <TaskEntity>[
        finishedTask('a', patternsAt(0, 8)),
        finishedTask('b', patternsAt(0, 9)),
      ],
      habits: <HabitEntity>[_longHabit],
      occurrences: <HabitOccurrenceEntity>[
        habitCheckIn(_longHabit, patternsAt(0)),
      ],
    );
    // The numbers are text in the semantics tree, not only painted bars.
    final Finder today = find.byKey(const ValueKey<String>('patterns-trend-6'));
    expect(
      find.descendant(
        of: today,
        matching: find.bySemanticsLabel(RegExp('2 tasks · 1 check-in')),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: today,
        matching: find.bySemanticsLabel(RegExp('Today')),
      ),
      findsWidgets,
    );
    handle.dispose();
  });

  testWidgets('the trend bar fill follows each row\'s share and is painted', (
    tester,
  ) async {
    // Today 2 tasks (the most), yesterday 1, the day before none.
    await pumpPatterns(
      tester,
      tasks: <TaskEntity>[
        finishedTask('a', patternsAt(0, 8)),
        finishedTask('b', patternsAt(0, 9)),
        finishedTask('c', patternsAt(1, 9)),
      ],
    );
    Size part(int row, String key) => tester.getSize(
      find.descendant(
        of: find.byKey(ValueKey<String>('patterns-trend-$row')),
        matching: find.byKey(ValueKey<String>(key)),
      ),
    );
    final double track = part(6, 'patterns-trend-track').width;
    expect(track, greaterThan(100));
    Size fill(int row) => part(row, 'patterns-trend-fill');
    expect(fill(6).width, moreOrLessEquals(track, epsilon: 0.5));
    expect(fill(6).height, greaterThan(0), reason: 'a full bar is painted');
    expect(fill(5).width, moreOrLessEquals(track / 2, epsilon: 0.5));
    expect(fill(5).height, greaterThan(0), reason: 'a half bar is painted');
    expect(fill(4).width, 0);
  });

  testWidgets('section titles are headings', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpFull(tester);
    for (final String title in <String>[
      'Habits',
      'Tasks finished and habit check-ins',
      'When you get things done',
      'Workload by day',
      'Missed items',
      'Level and points',
    ]) {
      expect(
        tester
            .getSemantics(find.text(title))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
        reason: title,
      );
    }
    handle.dispose();
  });
}
