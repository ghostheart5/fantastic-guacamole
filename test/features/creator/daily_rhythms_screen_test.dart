import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/features/creator/ui/daily_rhythms_screen.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late _Rhythms notifier;
  late AccountStorageScope scope;
  late List<HabitOccurrenceEntity> outcomes;

  setUp(() {
    scope = AccountStorageScope.authenticated('owner-a');
    outcomes = <HabitOccurrenceEntity>[];
    notifier = _Rhythms(outcomes);
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => scope),
        habitsProvider.overrideWith(() => notifier),
        habitOccurrencesProvider.overrideWith((ref) async => List.of(outcomes)),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const DailyRhythmsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows saved cadence and target; completion becomes read-only', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Evidence review'), findsOneWidget);
    expect(find.text('2 times per week · Active'), findsOneWidget);
    await tester.tap(find.text('Mark target completed'));
    await tester.pumpAndSettle();
    expect(notifier.completions, 1);
    expect(find.text('Completed this week'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark target completed'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Skip this week'),
          )
          .onPressed,
      isNull,
    );
    expect(outcomes, hasLength(1));
  });

  testWidgets('skip records one outcome and disables completion', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Skip this week'));
    await tester.pumpAndSettle();
    expect(outcomes.single.outcome, HabitOccurrenceOutcome.skipped);
    expect(notifier.completions, 0);
    expect(find.text('Skipped this week'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark target completed'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a restored period outcome cannot be recorded again', (
    tester,
  ) async {
    outcomes.add(_outcome(HabitOccurrenceOutcome.skipped));
    await open(tester);
    expect(find.text('Skipped this week'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark target completed'),
          )
          .onPressed,
      isNull,
    );
    expect(notifier.completions, 0);
  });

  testWidgets('pause disables outcomes and resume restores controls', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(find.text('2 times per week · Paused'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark target completed'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('2 times per week · Active'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark target completed'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('rename validates blank input and saves reviewed title', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byType(TextFormField),
      'Weekly evidence review',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly evidence review'), findsOneWidget);
    expect(notifier.renames, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancel removal keeps rhythm; explicit removal shows empty state',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(notifier.removals, 0);
      expect(find.text('Evidence review'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(notifier.removals, 1);
      expect(find.textContaining('No Daily Rhythms yet.'), findsOneWidget);
    },
  );

  testWidgets('account change while rename dialog is open prevents mutation', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Must not cross accounts',
    );
    scope = AccountStorageScope.authenticated('owner-b');
    container.invalidate(accountStorageScopeProvider);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.renames, 0);
  });

  testWidgets('signed-out view exposes no saved titles or mutation controls', (
    tester,
  ) async {
    scope = const AccountStorageScope.signedOut();
    await open(tester);
    expect(find.text('Sign in to view your Daily Rhythms.'), findsOneWidget);
    expect(find.text('Evidence review'), findsNothing);
    expect(find.text('Mark target completed'), findsNothing);
  });

  testWidgets('storage failure keeps rhythm and allows retry', (tester) async {
    notifier.failCompletion = true;
    await open(tester);
    await tester.tap(find.text('Mark target completed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save that change.'), findsOneWidget);
    expect(find.text('Not recorded this week'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark target completed'),
          )
          .onPressed,
      isNotNull,
    );
    expect(outcomes, isEmpty);
  });
}

HabitOccurrenceEntity _outcome(HabitOccurrenceOutcome outcome) =>
    HabitOccurrenceEntity(
      habitId: 'review',
      occurrenceKey: HabitOccurrenceCoordinator.occurrenceKeyFor(
        HabitCadence.weekly,
        DateTime.now(),
      ),
      operationId: 'operation',
      outcome: outcome,
      recordedAt: DateTime.now().toUtc(),
    );

class _Rhythms extends HabitsNotifier {
  _Rhythms(this.outcomes);
  final List<HabitOccurrenceEntity> outcomes;
  int completions = 0;
  int renames = 0;
  int removals = 0;
  bool failCompletion = false;

  @override
  Future<List<HabitEntity>> build() async => [
    HabitEntity(
      id: 'review',
      title: 'Evidence review',
      createdAt: DateTime(2026, 9, 1),
      cadence: HabitCadence.weekly,
      targetCount: 2,
    ),
  ];

  @override
  Future<HabitOccurrenceResult> completeHabit(String id) async {
    if (failCompletion) throw StateError('fixture write failure');
    completions++;
    final outcome = _outcome(HabitOccurrenceOutcome.completed);
    outcomes.add(outcome);
    ref.invalidate(habitOccurrencesProvider);
    return HabitOccurrenceResult(
      mutation: HabitOccurrenceMutation.applied,
      occurrence: outcome,
    );
  }

  @override
  Future<HabitOccurrenceResult> skipHabit(String id) async {
    final outcome = _outcome(HabitOccurrenceOutcome.skipped);
    outcomes.add(outcome);
    ref.invalidate(habitOccurrencesProvider);
    return HabitOccurrenceResult(
      mutation: HabitOccurrenceMutation.applied,
      occurrence: outcome,
    );
  }

  @override
  Future<void> toggleHabit(String id) async {
    final value = state.requireValue.single;
    state = AsyncData([
      value.copyWith(
        status: value.active ? HabitStatus.paused : HabitStatus.active,
      ),
    ]);
  }

  @override
  Future<void> renameHabit(String id, String title) async {
    renames++;
    state = AsyncData([state.requireValue.single.copyWith(title: title)]);
  }

  @override
  Future<void> removeHabit(String id) async {
    removals++;
    state = const AsyncData([]);
  }
}
