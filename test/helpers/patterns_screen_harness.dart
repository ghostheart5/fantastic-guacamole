import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/engine/patterns/patterns_engine.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/models/trajectory_summary_view.dart';
import 'package:fantastic_guacamole/state/models/user_progress.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Tuesday 2026-12-01 10:00 local: the moment every Patterns screen fixture is
/// worked out for. Fixtures use calendar fields only.
final DateTime patternsNow = DateTime(2026, 12, 1, 10);

/// [daysAgo] days before [patternsNow], at [hour].
DateTime patternsAt(int daysAgo, [int hour = 9]) => DateTime(
  patternsNow.year,
  patternsNow.month,
  patternsNow.day - daysAgo,
  hour,
);

TaskEntity finishedTask(String id, DateTime when, {String? title}) =>
    TaskEntity(
      id: id,
      title: title ?? 'Done $id',
      createdAt: patternsAt(60),
      isCompleted: true,
      completedAt: when,
    );

TaskEntity skippedTask(String id, DateTime when, {String? title}) => TaskEntity(
  id: id,
  title: title ?? 'Skipped $id',
  createdAt: patternsAt(60),
  isSkipped: true,
  skippedAt: when,
);

TaskEntity openTask(
  String id, {
  String? title,
  DateTime? scheduledFor,
  DateTime? dueDate,
  int? minutes,
}) => TaskEntity(
  id: id,
  title: title ?? 'Open $id',
  createdAt: patternsAt(60),
  scheduledFor: scheduledFor,
  dueDate: dueDate,
  estimatedDuration: minutes == null ? null : Duration(minutes: minutes),
);

HabitEntity patternsHabit(
  String id, {
  String title = 'Walk',
  int createdDaysAgo = 60,
  HabitCadence cadence = HabitCadence.daily,
}) => HabitEntity(
  id: id,
  title: title,
  createdAt: patternsAt(createdDaysAgo, 8),
  cadence: cadence,
);

HabitOccurrenceEntity habitCheckIn(
  HabitEntity habit,
  DateTime when, {
  HabitOccurrenceOutcome outcome = HabitOccurrenceOutcome.completed,
}) => HabitOccurrenceEntity(
  habitId: habit.id,
  occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, when),
  operationId: 'op-${habit.id}-${when.toIso8601String()}',
  outcome: outcome,
  recordedAt: when.toUtc(),
);

/// Records milestones instead of writing preferences.
class PatternsGuidanceSpy extends AdaptiveGuidanceNotifier {
  final List<GuidanceMilestone> recorded = <GuidanceMilestone>[];

  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: <GuidanceMilestone, DateTime>{},
    counts: <GuidanceMilestone, int>{},
    skippedLessons: <GuidanceLessonId>{},
    completedLessons: <GuidanceLessonId>{},
  );

  @override
  Future<void> record(
    GuidanceMilestone milestone, {
    bool Function()? shouldContinue,
  }) async => recorded.add(milestone);

  @override
  Future<void> recordIfMissing(
    GuidanceMilestone milestone, {
    bool Function()? shouldContinue,
  }) async => recorded.add(milestone);
}

const TrajectorySummaryView patternsTrajectory = TrajectorySummaryView(
  pendingTasks: 4,
  completedTasks: 27,
  completedToday: 3,
  level: 6,
  streak: 12,
  energy: 0.78,
  momentum: 0.66,
  adaptability: 0.71,
  lastCompletionXp: 25,
  lastCompletionQuality: 0.83,
  pressureIndex: 34,
  behaviorDivergence: 12,
  alert: '',
  predictionTitle: null,
  predictionOutcome: null,
  predictionProbability: null,
  predictionExplanation: null,
);

/// The Patterns screen over a fixed result worked out by the patterns engine
/// from [tasks], [habits] and [occurrences] for the selected range. The
/// provider is replaced (no account, no day-rollover timer); [state] can turn
/// the result into a loading or error state.
Future<ProviderContainer> pumpPatterns(
  WidgetTester tester, {
  List<TaskEntity> tasks = const <TaskEntity>[],
  List<HabitEntity> habits = const <HabitEntity>[],
  List<HabitOccurrenceEntity> occurrences = const <HabitOccurrenceEntity>[],
  DateTime? now,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Size size = const Size(400, 8000),
  double textScale = 1.0,
  ProgressionState? progression,
  AsyncValue<PatternsResult> Function(PatternsResult result)? state,
  PatternsGuidanceSpy? guidance,
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      patternsProvider.overrideWith((Ref ref) {
        final PatternsResult result = PatternsEngine.compute(
          tasks: tasks,
          habits: habits,
          occurrences: occurrences,
          now: now ?? patternsNow,
          rangeDays: ref.watch(patternsRangeDaysProvider),
        );
        return state?.call(result) ?? AsyncData<PatternsResult>(result);
      }),
      progressionProvider.overrideWithValue(
        progression ??
            const ProgressionState(
              progress: UserProgress(
                xp: 340,
                level: 3,
                streak: 4,
                longestStreak: 9,
              ),
              loading: false,
            ),
      ),
      trajectorySummaryProvider.overrideWithValue(patternsTrajectory),
      adaptiveGuidanceProvider.overrideWith(
        () => guidance ?? PatternsGuidanceSpy(),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? appTheme,
        locale: locale,
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: const ProgressionScreen(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// The Patterns list (the screen has one scrollable).
final Finder patternsScroll = find.byType(Scrollable).first;

/// Section keys, in their order on the page.
const List<String> patternsSectionKeys = <String>[
  'patterns-range',
  'patterns-habits',
  'patterns-trend',
  'patterns-when-done',
  'patterns-workload',
  'patterns-missed',
  'patterns-level',
];

Finder patternsSection(String key) => find.byKey(ValueKey<String>(key));

/// [matching] inside the section with [key].
Finder inPatternsSection(String key, Finder matching) =>
    find.descendant(of: patternsSection(key), matching: matching);
