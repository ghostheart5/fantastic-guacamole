import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/tutorial/guidance_catalogue.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/patterns_screen_harness.dart';

/// The rich fixture: four habits (daily done every day, weekly, daily with
/// today skipped, daily started today), five finished tasks (three on
/// Mondays, all in the morning), two skipped tasks (2 and 10 days ago), one
/// overdue task, two planned tasks and one undated task.
final HabitEntity walk = patternsHabit('walk', title: 'Walk');
final HabitEntity gym = patternsHabit(
  'gym',
  title: 'Gym',
  cadence: HabitCadence.weekly,
);
final HabitEntity stretch = patternsHabit('stretch', title: 'Stretch');
final HabitEntity read = patternsHabit(
  'read',
  title: 'Read',
  createdDaysAgo: 0,
);

final List<HabitEntity> richHabits = <HabitEntity>[walk, gym, stretch, read];

final List<HabitOccurrenceEntity> richCheckIns = <HabitOccurrenceEntity>[
  for (int day = 0; day < 7; day++) habitCheckIn(walk, patternsAt(day)),
  habitCheckIn(gym, patternsAt(0)),
  habitCheckIn(gym, patternsAt(14)),
  for (int day = 1; day <= 3; day++) habitCheckIn(stretch, patternsAt(day)),
  habitCheckIn(stretch, patternsAt(0), outcome: HabitOccurrenceOutcome.skipped),
];

final List<TaskEntity> richTasks = <TaskEntity>[
  // 2026-11-30, 11-23 and 11-16 are Mondays.
  finishedTask('m1', patternsAt(1)),
  finishedTask('m2', patternsAt(8)),
  finishedTask('m3', patternsAt(15)),
  finishedTask('tue', patternsAt(0, 8)),
  finishedTask('wed', patternsAt(6)),
  skippedTask('s1', patternsAt(2), title: 'Call the bank'),
  skippedTask('s2', patternsAt(10), title: 'Renew passport'),
  openTask('o1', title: 'Pay rent', dueDate: patternsAt(3)),
  openTask(
    'w1',
    title: 'Write report',
    scheduledFor: patternsAt(0, 14),
    minutes: 90,
  ),
  openTask(
    'w2',
    title: 'Plan trip',
    scheduledFor: patternsAt(-1, 9),
    minutes: 30,
  ),
  openTask('u1', title: 'Sort photos', minutes: 45),
];

Future<ProviderContainer> pumpRich(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  PatternsGuidanceSpy? guidance,
}) => pumpPatterns(
  tester,
  tasks: richTasks,
  habits: richHabits,
  occurrences: richCheckIns,
  locale: locale,
  guidance: guidance,
);

Future<void> chooseRange(WidgetTester tester, String label) async {
  await tester.tap(
    inPatternsSection('patterns-range', find.text(label)),
    warnIfMissed: false,
  );
  await tester.pump();
  await tester.pump();
}

/// The [PlainMetricRow] with [label] inside [section].
Finder row(String section, String label) => inPatternsSection(
  section,
  find.ancestor(of: find.text(label), matching: find.byType(PlainMetricRow)),
);

/// The value shown in the first row labelled [label] inside [section].
Finder rowValue(String section, String label, String value) =>
    find.descendant(of: row(section, label).first, matching: find.text(value));

void main() {
  testWidgets('a habit done every day of the last 7 shows "7 of 7 days" '
      'with its streak', (tester) async {
    await pumpPatterns(
      tester,
      habits: <HabitEntity>[walk],
      occurrences: <HabitOccurrenceEntity>[
        for (int day = 0; day < 7; day++) habitCheckIn(walk, patternsAt(day)),
      ],
    );
    final Finder habitRow = find.byKey(
      const ValueKey<String>('patterns-habit-walk'),
    );
    expect(
      find.descendant(of: habitRow, matching: find.text('Walk')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: habitRow, matching: find.text('7 of 7 days')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: habitRow,
        matching: find.textContaining('Streak: 7 days · Longest: 7 days'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('built on PlainScreen with none of the old widgets or '
      'headings', (tester) async {
    await pumpRich(tester);
    expect(find.byType(PlainScreen), findsOneWidget);
    expect(find.byType(AnimatedSystemBackground), findsNothing);
    expect(find.byType(TemporalGlassSurface), findsNothing);
    expect(find.byType(TemporalScreenHeader), findsNothing);
    for (final String removed in <String>[
      'PRESSURE',
      'CAPABILITY SIGNALS',
      'WHAT YOUR ACTIONS ARE CHANGING',
      'NEXT CAPABILITY TO PRACTICE',
      'COMPLETION MOMENTUM',
      'SAVED PROGRESS',
      'HABIT HISTORY',
      'LEVEL',
    ]) {
      expect(find.textContaining(removed), findsNothing, reason: removed);
    }
    expect(find.textContaining(RegExp(r'\d+/100')), findsNothing);
    // No capitals-only words anywhere (XP is the points unit).
    final List<String> shouting = <String>[
      for (final Element e in find.byType(Text).evaluate())
        if ((e.widget as Text).data case final String text)
          for (final String word in text.split(RegExp(r'[^A-Za-zÁÉÍÓÚÑ]+')))
            if (word.length > 1 && word != 'XP' && word == word.toUpperCase())
              '$word in "$text"',
    ];
    expect(shouting, isEmpty, reason: shouting.join(' / '));
  });

  testWidgets('the header is the tab name, Patterns is selected, and the '
      'sections come in order', (tester) async {
    await pumpRich(tester);
    expect(
      find.descendant(
        of: find.byType(PlainHeader),
        matching: find.text('Insights'),
      ),
      findsOneWidget,
    );
    final Finder switchFinder = find.byKey(InsightsDestinationSwitch.switchKey);
    expect(switchFinder, findsOneWidget);
    expect(
      find.text('Review your recorded history: tasks, habits and streaks'),
      findsOneWidget,
    );
    double top(Finder f) => tester.getTopLeft(f).dy;
    double previous = top(find.byType(PlainHeader));
    expect(top(switchFinder), greaterThan(previous));
    previous = top(switchFinder);
    for (final String key in patternsSectionKeys) {
      final double y = top(patternsSection(key));
      expect(y, greaterThan(previous), reason: key);
      previous = y;
    }
    expect(find.text('Time range'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Tasks finished and habit check-ins'), findsOneWidget);
    expect(find.text('When you get things done'), findsOneWidget);
    expect(find.text('Workload by day'), findsOneWidget);
    expect(find.text('Missed items'), findsOneWidget);
    expect(find.text('Level and points'), findsOneWidget);
  });

  group('habits', () {
    testWidgets('window by cadence, streaks, skipped today and not enough '
        'history', (tester) async {
      await pumpRich(tester);
      Finder inHabit(String id, Finder f) => find.descendant(
        of: find.byKey(ValueKey<String>('patterns-habit-$id')),
        matching: f,
      );
      expect(inHabit('walk', find.text('7 of 7 days')), findsOneWidget);
      expect(inHabit('gym', find.text('2 of 4 weeks')), findsOneWidget);
      expect(
        inHabit('gym', find.textContaining('Streak: 1 week · Longest: 1 week')),
        findsOneWidget,
      );
      expect(inHabit('stretch', find.text('3 of 7 days')), findsOneWidget);
      expect(
        inHabit('stretch', find.textContaining('Skipped today.')),
        findsOneWidget,
      );
      expect(
        inHabit('stretch', find.textContaining('Streak: 3 days')),
        findsOneWidget,
      );
      expect(
        inHabit('read', find.text('Not enough history yet')),
        findsOneWidget,
      );
      expect(
        inHabit('read', find.textContaining('Tracking started today.')),
        findsOneWidget,
      );
      expect(
        inPatternsSection('patterns-habits', find.text('From your records')),
        findsOneWidget,
      );
    });

    testWidgets('30 days widens the window: "7 of 30 days", "2 of 5 '
        'weeks"', (tester) async {
      await pumpRich(tester);
      await chooseRange(tester, '30 days');
      expect(find.text('7 of 30 days'), findsOneWidget);
      expect(find.text('2 of 5 weeks'), findsOneWidget);
    });

    for (final (String language, String sentence) in <(String, String)>[
      ('en', 'No active habits yet. Add a habit and check in to see it here.'),
      (
        'es',
        'Aún no tienes hábitos activos. Añade un hábito y regístralo para '
            'verlo aquí.',
      ),
    ]) {
      testWidgets('no habits: a truthful empty state ($language)', (
        tester,
      ) async {
        await pumpPatterns(tester, locale: Locale(language));
        expect(
          inPatternsSection('patterns-habits', find.text(sentence)),
          findsOneWidget,
        );
      });
    }
  });

  group('trend', () {
    testWidgets('7 days: daily rows with tasks and check-ins apart', (
      tester,
    ) async {
      await pumpRich(tester);
      const String s = 'patterns-trend';
      expect(
        inPatternsSection(s, find.text('The last 7 days, day by day.')),
        findsOneWidget,
      );
      expect(rowValue(s, 'Tasks finished', '3'), findsOneWidget);
      expect(rowValue(s, 'Habit check-ins', '11'), findsOneWidget);
      expect(rowValue(s, 'Wed 25 Nov', '1 task · 1 check-in'), findsOneWidget);
      expect(rowValue(s, 'Thu 26 Nov', '0 tasks · 1 check-in'), findsOneWidget);
      expect(
        rowValue(s, 'Sat 28 Nov', '0 tasks · 2 check-ins'),
        findsOneWidget,
      );
      expect(rowValue(s, 'Yesterday', '1 task · 2 check-ins'), findsOneWidget);
      expect(rowValue(s, 'Today', '1 task · 2 check-ins'), findsOneWidget);
      expect(
        inPatternsSection(s, find.text('From your records')),
        findsOneWidget,
      );
    });

    testWidgets('30 days: four weekly rows over the last 4 weeks', (
      tester,
    ) async {
      await pumpRich(tester);
      await chooseRange(tester, '30 days');
      const String s = 'patterns-trend';
      expect(
        inPatternsSection(s, find.text('The last 4 weeks, week by week.')),
        findsOneWidget,
      );
      expect(rowValue(s, 'Tasks finished', '5'), findsOneWidget);
      expect(
        rowValue(s, '4 Nov – 10 Nov', '0 tasks · 0 check-ins'),
        findsOneWidget,
      );
      expect(
        rowValue(s, '11 Nov – 17 Nov', '1 task · 1 check-in'),
        findsOneWidget,
      );
      expect(
        rowValue(s, '18 Nov – 24 Nov', '1 task · 0 check-ins'),
        findsOneWidget,
      );
      expect(
        rowValue(s, '25 Nov – 1 Dec', '3 tasks · 11 check-ins'),
        findsOneWidget,
      );
    });

    testWidgets('nothing recorded: the empty sentence', (tester) async {
      await pumpPatterns(tester);
      expect(
        inPatternsSection(
          'patterns-trend',
          find.text(
            'Nothing recorded in these days. Finish a task or check in a '
            'habit to see it here.',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('when you get things done', () {
    for (final String range in <String>['7 days', '30 days']) {
      testWidgets('names Mondays and mornings over the last 4 weeks '
          '($range selected)', (tester) async {
        await pumpRich(tester);
        if (range == '30 days') await chooseRange(tester, range);
        const String s = 'patterns-when-done';
        expect(
          inPatternsSection(
            s,
            find.text(
              'Finished tasks in the last 4 weeks (since Wed 4 Nov), '
              'whichever range is chosen.',
            ),
          ),
          findsOneWidget,
        );
        expect(rowValue(s, 'Finished tasks', '5'), findsOneWidget);
        expect(rowValue(s, 'Day of the week', 'Mondays'), findsOneWidget);
        expect(
          inPatternsSection(s, find.text('3 of 5 finished tasks')),
          findsOneWidget,
        );
        expect(rowValue(s, 'Part of the day', 'Mornings'), findsOneWidget);
        expect(
          inPatternsSection(
            s,
            find.text('5 of 5 finished tasks, between 6:00 and 11:59'),
          ),
          findsOneWidget,
        );
        expect(
          inPatternsSection(s, find.text('From your records')),
          findsOneWidget,
        );
      });
    }

    for (final int have in <int>[4, 0]) {
      testWidgets('not enough: says $have of the 5 needed', (tester) async {
        await pumpPatterns(tester, tasks: richTasks.take(have).toList());
        expect(
          inPatternsSection(
            'patterns-when-done',
            find.text(
              'Not enough finished tasks yet to see a pattern: $have of the '
              '5 needed.',
            ),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('no single day stands out', (tester) async {
      await pumpPatterns(
        tester,
        tasks: <TaskEntity>[
          finishedTask('a', patternsAt(1)),
          finishedTask('b', patternsAt(8)),
          finishedTask('c', patternsAt(0, 8)),
          finishedTask('d', patternsAt(7, 8)),
          finishedTask('e', patternsAt(3, 18)),
        ],
      );
      expect(
        rowValue(
          'patterns-when-done',
          'Day of the week',
          'No single day stands out',
        ),
        findsOneWidget,
      );
    });
  });

  group('workload by day', () {
    testWidgets('planned minutes per day and work with no day, from your '
        'plan', (tester) async {
      await pumpRich(tester);
      const String s = 'patterns-workload';
      expect(
        inPatternsSection(
          s,
          find.text(
            'Planned minutes for the next 7 days, based on your estimates.',
          ),
        ),
        findsOneWidget,
      );
      expect(rowValue(s, 'Today', '1 h 30 min'), findsOneWidget);
      expect(rowValue(s, 'Tomorrow', '30 min'), findsOneWidget);
      expect(rowValue(s, 'Thu 3 Dec', '0 min'), findsOneWidget);
      expect(rowValue(s, 'Not on a day', '1 h 10 min'), findsOneWidget);
      expect(
        inPatternsSection(
          s,
          find.text(
            '2 tasks with no date, a date that has passed, or overdue; 1 '
            'with no estimate saved',
          ),
        ),
        findsOneWidget,
      );
      expect(
        inPatternsSection(
          s,
          find.text(
            'All figures are based on your estimates. Tasks with no '
            'estimate saved use a standard length.',
          ),
        ),
        findsOneWidget,
      );
      expect(inPatternsSection(s, find.text('From your plan')), findsOneWidget);
      expect(
        inPatternsSection(s, find.text('From your records')),
        findsNothing,
      );
    });

    testWidgets('all work on a day: "None" for work with no day', (
      tester,
    ) async {
      await pumpPatterns(
        tester,
        tasks: <TaskEntity>[
          openTask('w1', scheduledFor: patternsAt(0, 14), minutes: 20),
        ],
      );
      expect(
        rowValue('patterns-workload', 'Not on a day', 'None'),
        findsOneWidget,
      );
      expect(find.textContaining('Tasks with no estimate saved'), findsNothing);
    });

    testWidgets('nothing planned: the empty sentence with Add something', (
      tester,
    ) async {
      final PatternsGuidanceSpy guidance = PatternsGuidanceSpy();
      final ProviderContainer container = await pumpPatterns(
        tester,
        guidance: guidance,
      );
      expect(
        inPatternsSection(
          'patterns-workload',
          find.text(
            'Nothing planned for the next 7 days and no open work without '
            'a day.',
          ),
        ),
        findsOneWidget,
      );
      final Finder add = find.widgetWithText(OutlinedButton, 'Add something');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      expect(container.read(appFlowProvider), AppView.creator);
      expect(guidance.recorded, <GuidanceMilestone>[
        GuidanceMilestone.firstProgressionReview,
      ]);
    });

    testWidgets('Open My plan goes to My plan and records the review', (
      tester,
    ) async {
      final PatternsGuidanceSpy guidance = PatternsGuidanceSpy();
      final ProviderContainer container = await pumpRich(
        tester,
        guidance: guidance,
      );
      final Finder open = find.widgetWithText(OutlinedButton, 'Open My plan');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pump();
      expect(container.read(appFlowProvider), AppView.timeline);
      expect(guidance.recorded, <GuidanceMilestone>[
        GuidanceMilestone.firstProgressionReview,
      ]);
    });
  });

  group('missed items', () {
    testWidgets('counts and names in the range; overdue now', (tester) async {
      await pumpRich(tester);
      const String s = 'patterns-missed';
      expect(
        inPatternsSection(
          s,
          find.text('Counts from the last 7 days, and work overdue now.'),
        ),
        findsOneWidget,
      );
      expect(rowValue(s, 'Tasks skipped', '1'), findsOneWidget);
      expect(inPatternsSection(s, find.text('Call the bank')), findsOneWidget);
      expect(inPatternsSection(s, find.text('Renew passport')), findsNothing);
      expect(rowValue(s, 'Overdue now', '1'), findsOneWidget);
      expect(inPatternsSection(s, find.text('Pay rent')), findsOneWidget);
      expect(
        rowValue(s, 'Habit periods missed or skipped', '5'),
        findsOneWidget,
      );
      expect(
        inPatternsSection(s, find.text('Stretch · Tue 1 Dec · skipped')),
        findsOneWidget,
      );
      expect(
        inPatternsSection(s, find.text('Gym · week of 23 Nov · missed')),
        findsOneWidget,
      );
      expect(
        inPatternsSection(s, find.text('From your records')),
        findsOneWidget,
      );
      for (final String blame in <String>['fail', 'Fail', 'bad', 'should']) {
        expect(inPatternsSection(s, find.textContaining(blame)), findsNothing);
      }
    });

    testWidgets('30 days changes the list', (tester) async {
      await pumpRich(tester);
      await chooseRange(tester, '30 days');
      const String s = 'patterns-missed';
      expect(
        inPatternsSection(
          s,
          find.text('Counts from the last 30 days, and work overdue now.'),
        ),
        findsOneWidget,
      );
      expect(rowValue(s, 'Tasks skipped', '2'), findsOneWidget);
      expect(inPatternsSection(s, find.text('Renew passport')), findsOneWidget);
      expect(
        inPatternsSection(s, find.textContaining(RegExp(r'^and \d+ more$'))),
        findsOneWidget,
      );
    });

    testWidgets('nothing recorded: the empty sentence', (tester) async {
      await pumpPatterns(tester);
      expect(
        inPatternsSection(
          'patterns-missed',
          find.text(
            'Nothing recorded yet. Add a task or a habit to see it here.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tasks but nothing missed: zero counts, not an error', (
      tester,
    ) async {
      await pumpPatterns(
        tester,
        tasks: <TaskEntity>[finishedTask('a', patternsAt(1))],
      );
      expect(rowValue('patterns-missed', 'Tasks skipped', '0'), findsOneWidget);
      expect(rowValue('patterns-missed', 'Overdue now', '0'), findsOneWidget);
      expect(
        rowValue(
          'patterns-missed',
          'Habit periods missed or skipped',
          'No habits yet',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('provenance: records and plan only, never Estimate or AI', (
    tester,
  ) async {
    await pumpRich(tester);
    expect(find.text('From your records'), findsNWidgets(4));
    expect(find.text('From your plan'), findsOneWidget);
    expect(find.text('Estimate'), findsNothing);
    expect(find.text('AI interpretation'), findsNothing);
    expect(find.textContaining('estimates, not promises'), findsNothing);
  });

  testWidgets('level and points', (tester) async {
    await pumpRich(tester);
    const String s = 'patterns-level';
    expect(rowValue(s, 'Level', '3'), findsOneWidget);
    expect(rowValue(s, 'Points', '340 XP'), findsOneWidget);
    expect(rowValue(s, 'Streak', '4 days'), findsOneWidget);
    expect(rowValue(s, 'Longest streak', '9 days'), findsOneWidget);
    expect(rowValue(s, 'Milestones reached', '2 of 5'), findsOneWidget);
    expect(inPatternsSection(s, find.text('Share progress')), findsOneWidget);
  });

  testWidgets('no milestones yet: a plain "None yet"', (tester) async {
    await pumpPatterns(tester, milestones: (completed: 0, total: 0));
    expect(
      rowValue('patterns-level', 'Milestones reached', 'None yet'),
      findsOneWidget,
    );
  });

  testWidgets('first read: no figures, level and points still shown', (
    tester,
  ) async {
    await pumpPatterns(
      tester,
      state: (_) => const AsyncLoading<PatternsResult>(),
    );
    expect(find.text('Reading your records…'), findsOneWidget);
    expect(find.text('Habits'), findsNothing);
    expect(find.text('Level and points'), findsOneWidget);
    // The spinner never settles; unmount it before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('records that cannot be read: no figures, and Retry', (
    tester,
  ) async {
    await pumpPatterns(
      tester,
      state: (_) =>
          const AsyncError<PatternsResult>('broken', StackTrace.empty),
    );
    expect(
      find.text('Your records could not be read, so no figures are shown.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    expect(find.text('Habits'), findsNothing);
    // A refresh that keeps the earlier result on screen is covered in
    // patterns_live_test.dart with the real provider.
  });

  testWidgets('Spanish: names, windows and units', (tester) async {
    await pumpRich(tester, locale: const Locale('es'));
    expect(
      find.descendant(
        of: find.byType(PlainHeader),
        matching: find.text('Perspectivas'),
      ),
      findsOneWidget,
    );
    expect(find.text('7 de 7 días'), findsOneWidget);
    expect(find.text('2 de 4 semanas'), findsOneWidget);
    expect(
      find.textContaining('Racha: 7 días · Más larga: 7 días'),
      findsOneWidget,
    );
    expect(find.textContaining('Omitido hoy.'), findsOneWidget);
    expect(find.text('Aún no hay suficiente historial'), findsOneWidget);
    expect(find.text('Los últimos 7 días, día a día.'), findsOneWidget);
    expect(find.text('1 tarea · 2 registros'), findsNWidgets(2));
    expect(find.text('Los lunes'), findsOneWidget);
    expect(find.text('Por la mañana'), findsOneWidget);
    expect(
      find.text(
        'Tareas terminadas en las últimas 4 semanas (desde el mié 4 nov), '
        'sea cual sea el periodo elegido.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sin día asignado'), findsOneWidget);
    expect(find.text('Lo que quedó sin hacer'), findsOneWidget);
    expect(find.text('Stretch · mar 1 dic · omitido'), findsOneWidget);
    expect(find.text('Nivel y puntos'), findsOneWidget);
    expect(find.text('De tus registros'), findsNWidgets(4));
    expect(find.text('De tu plan'), findsOneWidget);
    expect(find.text('Abrir Mi plan'), findsOneWidget);
    expect(find.text('Estimación'), findsNothing);
  });

  testWidgets('the range choice drives patternsRangeDaysProvider', (
    tester,
  ) async {
    final ProviderContainer container = await pumpRich(tester);
    expect(container.read(patternsRangeDaysProvider), 7);
    await chooseRange(tester, '30 days');
    expect(container.read(patternsRangeDaysProvider), 30);
    await chooseRange(tester, '7 days');
    expect(container.read(patternsRangeDaysProvider), 7);
  });
}
