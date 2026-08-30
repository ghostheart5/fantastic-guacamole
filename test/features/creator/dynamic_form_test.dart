import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Creator defaults to Task with the complete task field set', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CreatorFormData? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              onSubmit: (CreatorFormData data) async => submitted = data,
            ),
          ),
        ),
      ),
    );

    expect(find.text('CREATE TASK'), findsOneWidget);
    expect(find.byKey(const Key('creator-type-selector')), findsOneWidget);
    expect(find.text('ACTIVE GOAL'), findsOneWidget);
    expect(find.text('ESTIMATED DURATION'), findsOneWidget);
    expect(find.text('PRIORITY'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('DEADLINE'), findsOneWidget);

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Ship the launch task');
    await tester.ensureVisible(find.text('CREATE TASK'));
    await tester.tap(find.text('CREATE TASK'));
    await tester.pump();

    expect(submitted?.type, 'Task');
    expect(submitted?.estimatedDuration, const Duration(minutes: 30));
  });

  testWidgets('Task links an active goal and submits an estimate', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CreatorFormData? submitted;
    final GoalEntity activeGoal = GoalEntity(
      id: 'goal-1',
      title: 'Ship ChronoSpark',
      createdAt: DateTime(2026, 8, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              activeGoals: <GoalEntity>[activeGoal],
              onSubmit: (CreatorFormData data) async => submitted = data,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField && widget.decoration?.hintText == 'Title *',
      ),
      'Prepare release evidence',
    );
    await tester.tap(find.byKey(const Key('creator-task-goal-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ship ChronoSpark').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('creator-task-estimate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 minutes').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Schedule date and time...'));
    await tester.tap(find.text('Schedule date and time...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add deadline...'));
    await tester.tap(find.text('Add deadline...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('CREATE TASK'));
    await tester.tap(find.text('CREATE TASK'));
    await tester.pump();

    expect(submitted?.goalId, 'goal-1');
    expect(submitted?.estimatedDuration, const Duration(minutes: 45));
    expect(submitted?.scheduledFor, isNotNull);
    expect(submitted?.dueDate, isNotNull);
  });

  testWidgets('Goal exposes target date without task semantics', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CreatorFormData? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              initialType: CreatorFormKind.goal,
              onSubmit: (CreatorFormData data) async => submitted = data,
            ),
          ),
        ),
      ),
    );

    expect(find.text('TARGET DATE'), findsOneWidget);
    expect(find.text('PRIORITY'), findsNothing);
    expect(find.text('SCHEDULE'), findsNothing);
    expect(find.text('DEADLINE'), findsNothing);
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField && widget.decoration?.hintText == 'Title *',
      ),
      'Reach launch confidence',
    );
    await tester.tap(find.text('Add target date...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE GOAL'));
    await tester.pump();

    expect(submitted?.kind, CreatorFormKind.goal);
    expect(submitted?.targetDate, isNotNull);
  });

  testWidgets('Daily Rhythm submits cadence and recurrence', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CreatorFormData? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              initialType: CreatorFormKind.habit,
              onSubmit: (CreatorFormData data) async => submitted = data,
            ),
          ),
        ),
      ),
    );

    expect(find.text('CADENCE / RECURRENCE'), findsOneWidget);
    expect(find.byKey(const Key('creator-rhythm-cadence')), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField && widget.decoration?.hintText == 'Title *',
      ),
      'Morning reset',
    );
    await tester.tap(find.text('Weekly'));
    await tester.tap(find.byKey(const Key('creator-rhythm-increase')));
    await tester.tap(find.text('CREATE DAILY RHYTHM'));
    await tester.pump();

    expect(submitted?.kind, CreatorFormKind.habit);
    expect(submitted?.habitCadence, HabitCadence.weekly);
    expect(submitted?.habitTargetCount, 2);
    expect(submitted?.recurrenceRule.name, 'weekly');
  });

  testWidgets('Note uses only title and body and never task semantics', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CreatorFormData? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              initialType: CreatorFormKind.note,
              onSubmit: (CreatorFormData data) async => submitted = data,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Body (optional)'), findsOneWidget);
    for (final String taskField in <String>[
      'ACTIVE GOAL',
      'ESTIMATED DURATION',
      'PRIORITY',
      'SCHEDULE',
      'DEADLINE',
      'CADENCE / RECURRENCE',
      'TARGET DATE',
    ]) {
      expect(find.text(taskField), findsNothing, reason: taskField);
    }
    final List<TextField> fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList(growable: false);
    await tester.enterText(find.byWidget(fields.first), 'Decision context');
    await tester.enterText(find.byWidget(fields.last), 'Keep this as a note.');
    await tester.tap(find.text('CREATE NOTE'));
    await tester.pump();

    expect(submitted?.kind, CreatorFormKind.note);
    expect(submitted?.description, 'Keep this as a note.');
    expect(submitted?.scheduledFor, isNull);
    expect(submitted?.goalId, isNull);
    expect(submitted?.dueDate, isNull);
  });

  testWidgets('all Creator modes fit a 320 logical pixel viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final CreatorFormKind type in CreatorFormKind.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicForm(initialType: type, onSubmit: (_) async {}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: type.name);
    }
  });

  testWidgets('Planner preview prefills Creator but does not submit', (
    WidgetTester tester,
  ) async {
    CreatorFormData? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              initialDraftId: 'planner-draft-1',
              initialTitle: 'Review one release decision',
              initialDescription: 'Transient Planner preview.',
              onSubmit: (CreatorFormData data) async => submitted = data,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    final Finder descriptionField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Description (optional)',
    );
    expect(
      tester.widget<TextField>(titleField).controller?.text,
      'Review one release decision',
    );
    expect(
      tester.widget<TextField>(descriptionField).controller?.text,
      'Transient Planner preview.',
    );
    expect(submitted, isNull);

    await tester.ensureVisible(find.text('CREATE TASK'));
    await tester.tap(find.text('CREATE TASK'));
    await tester.pump();
    expect(submitted?.title, 'Review one release decision');
  });

  testWidgets('removing a Planner preview clears its transient prefill', (
    WidgetTester tester,
  ) async {
    String? draftId = 'planner-draft-1';
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              rebuild = setState;
              return SingleChildScrollView(
                child: DynamicForm(
                  initialDraftId: draftId,
                  initialTitle: 'Transient title',
                  initialDescription: 'Transient description',
                  onSubmit: (_) async {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    rebuild(() => draftId = null);
    await tester.pump();

    final Iterable<TextField> fields = tester.widgetList<TextField>(
      find.byType(TextField),
    );
    expect(fields.first.controller?.text, isEmpty);
    expect(fields.elementAt(1).controller?.text, isEmpty);
  });

  testWidgets(
    'Planner prefill defers tutorial state updates until after build',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              ref.watch(_draftTitleValidityProvider);
              return MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: DynamicForm(
                      initialDraftId: 'planner-draft-1',
                      initialTitle: 'Review the release task',
                      onTitleValidityChanged: ref
                          .read(_draftTitleValidityProvider.notifier)
                          .set,
                      onSubmit: (_) async {},
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(container.read(_draftTitleValidityProvider), isTrue);
    },
  );

  testWidgets('schedule picker pauses guidance while its dialog is open', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool pickerVisible = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              onPickerVisibilityChanged: (bool value) => pickerVisible = value,
              onSubmit: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Schedule date and time...'));
    await tester.tap(find.text('Schedule date and time...'));
    await tester.pumpAndSettle();
    expect(pickerVisible, isTrue);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pickerVisible, isFalse);
  });

  testWidgets('guided first task requires real choices and a schedule', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool titleReady = false;
    bool priorityChosen = false;
    bool submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              initialType: CreatorFormKind.note,
              guidedFirstTask: true,
              onTitleValidityChanged: (bool value) => titleReady = value,
              onPriorityChosen: () => priorityChosen = true,
              onSubmit: (_) async => submitted = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('CREATE TASK'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('Body (optional)'), findsNothing);
    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Prepare the first launch');
    await tester.tap(find.bySemanticsLabel('Set priority level 4'));
    await tester.ensureVisible(find.text('CREATE TASK'));
    await tester.tap(find.text('CREATE TASK'));
    await tester.pump();

    expect(titleReady, isTrue);
    expect(priorityChosen, isTrue);
    expect(submitted, isFalse);
    expect(
      find.text(
        'Choose a date and time so your first task can appear on Timeline.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed task save preserves the form and shows a retry message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              onSubmit: (_) async {
                throw StateError('storage unavailable');
              },
            ),
          ),
        ),
      ),
    );

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Keep this task');
    await tester.ensureVisible(find.text('CREATE TASK'));
    await tester.tap(find.text('CREATE TASK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'The task could not be saved. Your entry is still here - retry.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(titleField).controller?.text,
      'Keep this task',
    );
  });
}

final NotifierProvider<_DraftTitleValidityNotifier, bool>
_draftTitleValidityProvider =
    NotifierProvider<_DraftTitleValidityNotifier, bool>(
      _DraftTitleValidityNotifier.new,
    );

class _DraftTitleValidityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
