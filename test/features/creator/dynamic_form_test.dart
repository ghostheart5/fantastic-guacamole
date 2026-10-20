import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final rule in [RecurrenceRule.daily, RecurrenceRule.weekly]) {
    testWidgets('task frequency $rule survives form submission', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CreatorFormData? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicForm(onSubmit: (data) async => submitted = data),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField).first,
        'Synthetic recurring task',
      );
      await _expandTaskOptions(tester);
      await tester.tap(find.byKey(const Key('creator-task-repeat')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(rule == RecurrenceRule.daily ? 'Daily' : 'Weekly').last,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pump();
      expect(submitted?.recurrenceRule, rule);
    });
  }

  for (final int minutes in <int>[5, 10]) {
    testWidgets('Creator submits a $minutes-minute task without rounding up', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1800);
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
      await tester.enterText(find.byType(TextField).first, 'Sort three bills');
      await _expandTaskOptions(tester);
      await tester.tap(find.byKey(const Key('creator-task-estimate')));
      await tester.pumpAndSettle();
      expect(find.text('1 hours 30 min'), findsNothing);
      expect(find.text('1 hour 30 min'), findsOneWidget);
      await tester.tap(find.text('$minutes minutes').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pump();
      expect(submitted?.estimatedDuration, Duration(minutes: minutes));
      expect(submitted?.title, 'Sort three bills');
    });
  }

  testWidgets('input labels remain accessible after text is entered', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(onSubmit: (_) async {}),
          ),
        ),
      ),
    );
    final title = find.bySemanticsLabel(RegExp('Title, required'));
    expect(title, findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'A saved intention');
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Title, required')), findsOneWidget);
    await _expandDescription(tester);
    expect(
      find.bySemanticsLabel(RegExp('Description \\(optional\\)')),
      findsOneWidget,
    );
    semantics.dispose();
  });
  testWidgets('Task options start closed and defaults survive a simple save', (
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

    expect(find.text('Save task'), findsOneWidget);
    expect(find.byKey(const Key('creator-type-selector')), findsOneWidget);
    expect(find.text('Link to a goal (optional)'), findsNothing);
    expect(find.text('About how long?'), findsNothing);
    expect(find.text('PRIORITY'), findsNothing);
    expect(find.text('When to work on it (optional)'), findsNothing);
    expect(find.text('Due date (optional)'), findsNothing);
    expect(find.byKey(const Key('creator-task-options')), findsOneWidget);

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Ship the launch task');
    await tester.ensureVisible(find.text('Save task'));
    await tester.tap(find.text('Save task'));
    await tester.pump();

    expect(submitted?.type, 'Task');
    expect(submitted?.estimatedDuration, const Duration(minutes: 30));
    expect(submitted?.priority, 3);
    expect(submitted?.scheduledFor, isNull);
    expect(submitted?.recurrenceRule, RecurrenceRule.none);
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
    await _expandTaskOptions(tester);
    await tester.tap(find.byKey(const Key('creator-task-goal-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ship ChronoSpark').last);
    await tester.pumpAndSettle();
    await _expandTaskOptions(tester);
    await tester.tap(find.byKey(const Key('creator-task-estimate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 minutes').last);
    await tester.pumpAndSettle();
    await _expandTaskOptions(tester);
    await tester.ensureVisible(find.text('Schedule date and time...'));
    await tester.tap(find.text('Schedule date and time...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'^When to work on it \(optional\): .+')),
      findsOneWidget,
      reason: 'The selected date and time must be announced, not just shown.',
    );
    await tester.ensureVisible(find.text('Add deadline...'));
    await tester.tap(find.text('Add deadline...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save task'));
    await tester.tap(find.text('Save task'));
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

    expect(find.text('Target date (optional)'), findsNothing);
    await tester.tap(find.byKey(const Key('creator-goal-options')));
    await tester.pumpAndSettle();
    expect(find.text('Target date (optional)'), findsOneWidget);
    expect(find.text('PRIORITY'), findsNothing);
    expect(find.text('When to work on it (optional)'), findsNothing);
    expect(find.text('Due date (optional)'), findsNothing);
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
    await tester.tap(find.text('Save goal'));
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
        theme: appTheme,
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

    expect(find.text('How often?'), findsOneWidget);
    expect(find.byKey(const Key('creator-rhythm-cadence')), findsOneWidget);
    final increase = find.byKey(const Key('creator-rhythm-increase'));
    final foreground = IconTheme.of(
      tester.element(find.byIcon(Icons.add_rounded)),
    ).color!;
    final background = tester
        .widget<IconButton>(increase)
        .style!
        .backgroundColor!
        .resolve({})!;
    final light = foreground.computeLuminance() > background.computeLuminance()
        ? foreground.computeLuminance()
        : background.computeLuminance();
    final dark = foreground.computeLuminance() < background.computeLuminance()
        ? foreground.computeLuminance()
        : background.computeLuminance();
    expect(
      (light + .05) / (dark + .05),
      greaterThanOrEqualTo(3),
      reason:
          'The rendered plus icon must be distinguishable from its filled background.',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is TextField && widget.decoration?.hintText == 'Title *',
      ),
      'Morning reset',
    );
    await tester.tap(find.text('Weekly'));
    await tester.tap(find.byKey(const Key('creator-rhythm-increase')));
    await tester.tap(find.text('Save habit'));
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
      'Link to a goal (optional)',
      'About how long?',
      'PRIORITY',
      'When to work on it (optional)',
      'Due date (optional)',
      'How often?',
      'Target date (optional)',
    ]) {
      expect(find.text(taskField), findsNothing, reason: taskField);
    }
    final List<TextField> fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList(growable: false);
    await tester.enterText(find.byWidget(fields.first), 'Decision context');
    await tester.enterText(find.byWidget(fields.last), 'Keep this as a note.');
    await tester.tap(find.text('Save note'));
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
              initialEstimatedDuration: const Duration(minutes: 20),
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
    await _expandDescription(tester);
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

    await tester.ensureVisible(find.text('Save task'));
    await tester.tap(find.text('Save task'));
    await tester.pump();
    expect(submitted?.title, 'Review one release decision');
    expect(submitted?.estimatedDuration, const Duration(minutes: 20));
  });

  testWidgets(
    'Planner estimate respects edits, draft replacement, and discard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? draftId = 'first-plan';
      int minutes = 20;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SingleChildScrollView(
                  child: DynamicForm(
                    initialDraftId: draftId,
                    initialTitle: 'Review the estimate',
                    initialEstimatedDuration: draftId == null
                        ? null
                        : Duration(minutes: minutes),
                    onSubmit: (_) async {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await _expandTaskOptions(tester);
      final picker = find.byKey(const Key('creator-task-estimate'));
      Duration? estimate() =>
          tester.widget<DropdownButton<Duration>>(picker).value;
      expect(estimate(), const Duration(minutes: 20));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('45 minutes').last);
      await tester.pumpAndSettle();
      rebuild(() {});
      await tester.pump();
      expect(estimate(), const Duration(minutes: 45));
      expect(
        tester
            .widget<DropdownButton<Duration>>(picker)
            .items!
            .where((item) => item.value == const Duration(minutes: 20)),
        hasLength(1),
      );
      rebuild(() {
        draftId = 'smaller-plan';
        minutes = 7;
      });
      await tester.pump();
      expect(estimate(), const Duration(minutes: 7));
      rebuild(() => draftId = null);
      await tester.pump();
      expect(estimate(), const Duration(minutes: 30));
      expect(tester.takeException(), isNull);
    },
  );

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

    await _expandDescription(tester);
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

    await _expandTaskOptions(tester);
    await tester.ensureVisible(find.text('Schedule date and time...'));
    await tester.tap(find.text('Schedule date and time...'));
    await tester.pumpAndSettle();
    expect(pickerVisible, isTrue);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pickerVisible, isFalse);
  });

  testWidgets('schedule picker does not restore focus to the title field', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(onSubmit: (_) async {}),
          ),
        ),
      ),
    );

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.tap(titleField);
    await tester.enterText(titleField, 'Keep this title intact');
    expect(tester.testTextInput.isVisible, isTrue);

    await _expandTaskOptions(tester);
    final Finder schedule = find.text('Schedule date and time...');
    await tester.ensureVisible(schedule);
    await tester.tap(schedule);
    await tester.pumpAndSettle();
    final Finder datePickerOk = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.widgetWithText(TextButton, 'OK'),
    );
    await tester.tap(datePickerOk);
    await tester.pumpAndSettle();
    final Finder timePickerOk = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.widgetWithText(TextButton, 'OK'),
    );
    await tester.tap(timePickerOk);
    await tester.pumpAndSettle();

    final EditableText titleEditor = tester.widget<EditableText>(
      find.descendant(of: titleField, matching: find.byType(EditableText)),
    );
    expect(titleEditor.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(titleEditor.controller.text, 'Keep this title intact');
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

    expect(find.text('Save task'), findsOneWidget);
    expect(find.text('When to work on it'), findsOneWidget);
    expect(find.text('Body (optional)'), findsNothing);
    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Prepare the first launch');
    await tester.tap(find.bySemanticsLabel('Set priority level 4'));
    await tester.ensureVisible(find.text('Save task'));
    await tester.tap(find.text('Save task'));
    await tester.pump();

    expect(titleReady, isTrue);
    expect(priorityChosen, isTrue);
    expect(submitted, isFalse);
    expect(
      find.text('Choose a date and time to see this task in your schedule.'),
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
    await tester.ensureVisible(find.text('Save task'));
    await tester.tap(find.text('Save task'));
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

Future<void> _expandTaskOptions(WidgetTester tester) async {
  final options = find.byKey(const Key('creator-task-options'));
  if (options.evaluate().isEmpty ||
      find.byKey(const Key('creator-task-repeat')).evaluate().isNotEmpty) {
    return;
  }
  await tester.ensureVisible(options);
  await tester.tap(find.text('Task options (optional)'));
  await tester.pumpAndSettle();
}

Future<void> _expandDescription(WidgetTester tester) async {
  final toggle = find.byKey(const Key('creator-description-options'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}
