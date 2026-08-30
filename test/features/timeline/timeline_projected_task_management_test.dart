import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tutorial evidence matches only the Creator receipt task', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildContainer(
      expectedTutorialTaskIds: <String>{_managedTask.id},
    );
    addTearDown(container.dispose);

    await _pumpTimeline(tester, container);
    await tester.pump();

    expect(
      find.byKey(FirstRunTutorialTargets.timelineEvidence),
      findsOneWidget,
    );
    expect(container.read(timelineTutorialEvidenceProvider), _managedTask.id);
  });

  testWidgets('unrelated task cannot become first-run Timeline evidence', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildContainer(
      expectedTutorialTaskIds: const <String>{'different-receipt-task'},
    );
    addTearDown(container.dispose);

    await _pumpTimeline(tester, container);
    await tester.pump();

    expect(find.byKey(FirstRunTutorialTargets.timelineEvidence), findsNothing);
    expect(container.read(timelineTutorialEvidenceProvider), isNull);
  });

  testWidgets('loading saved tasks is not presented as an empty Timeline', (
    WidgetTester tester,
  ) async {
    final Completer<List<Task>> tasks = Completer<List<Task>>();
    final ProviderContainer container = _buildContainer(
      tasksLoader: (Ref ref) => tasks.future,
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);

    expect(find.text('Loading your Timeline'), findsOneWidget);
    expect(find.text('No saved activity in this view'), findsNothing);
    tasks.complete(const <Task>[]);
  });

  testWidgets('saved activity remains visible while task projections load', (
    WidgetTester tester,
  ) async {
    final Completer<List<Task>> tasks = Completer<List<Task>>();
    final ProviderContainer container = _buildContainer(
      baseEvents: <TimelineEventEntity>[_baseEvent],
      tasksLoader: (Ref ref) => tasks.future,
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);

    expect(find.text(_baseEvent.title), findsOneWidget);
    expect(
      find.textContaining('Task projections are still loading'),
      findsOneWidget,
    );
    expect(find.text('No saved activity in this view'), findsNothing);
    tasks.complete(const <Task>[]);
  });

  testWidgets('task load failure has an explicit retry and then recovers', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    final ProviderContainer container = _buildContainer(
      tasksLoader: (Ref ref) async {
        calls += 1;
        if (calls == 1) {
          throw StateError('read failed');
        }
        return <Task>[_managedTask];
      },
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);
    await tester.pump();

    expect(find.text('Timeline tasks could not be loaded'), findsOneWidget);
    expect(find.text('No saved activity in this view'), findsNothing);

    await tester.tap(find.byKey(const Key('timeline-task-source-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text(_managedTask.title), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('task failure does not hide valid saved activity', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildContainer(
      baseEvents: <TimelineEventEntity>[_baseEvent],
      tasksLoader: (Ref ref) async => throw StateError('read failed'),
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);
    await tester.pump();

    expect(find.text(_baseEvent.title), findsOneWidget);
    expect(
      find.textContaining('Task projections are unavailable'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('timeline-task-notice-retry')), findsOneWidget);
    expect(find.text('No saved activity in this view'), findsNothing);
  });

  testWidgets('corrupt persistence is never presented as a true empty state', (
    WidgetTester tester,
  ) async {
    late _TimelineNotifier timelineNotifier;
    final ProviderContainer container = _buildContainer(
      persistenceCorrupted: true,
      tasksLoader: (Ref ref) async => const <Task>[],
      onTimelineNotifierBuilt: (_TimelineNotifier value) =>
          timelineNotifier = value,
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);
    await tester.pump();

    expect(
      find.text('Saved Timeline activity could not be read'),
      findsOneWidget,
    );
    expect(find.text('No saved activity in this view'), findsNothing);
    expect(find.byKey(const Key('timeline-persistence-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-persistence-retry')));
    await tester.pump();
    expect(find.text('Repair saved Timeline activity?'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('timeline-confirm-persistence-repair')),
    );
    await tester.pump();
    await tester.pump();
    expect(timelineNotifier.persistenceRepairCalls, 1);
  });

  testWidgets('simultaneous persistence and task failures are both visible', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildContainer(
      persistenceCorrupted: true,
      tasksLoader: (Ref ref) async => throw StateError('read failed'),
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);
    await tester.pump();

    expect(
      find.text('Saved Timeline activity could not be read'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Task projections are unavailable'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('timeline-task-notice-retry')), findsOneWidget);
  });

  testWidgets('resolved empty sources show a truthful saved-data empty state', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildContainer(
      tasksLoader: (Ref ref) async => const <Task>[],
    );
    addTearDown(container.dispose);

    await _pumpTimelineShell(tester, container);
    await tester.pump();

    expect(find.text('No saved activity in this view'), findsOneWidget);
    expect(find.text('Loading your Timeline'), findsNothing);
  });

  testWidgets('schedule-only task is never presented as due or overdue', (
    WidgetTester tester,
  ) async {
    final Task scheduledTask = Task(
      id: 'schedule-only',
      title: 'Scheduled work block',
      priority: 3,
      difficulty: 2,
      energyRequired: 2,
      scheduledFor: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final ProviderContainer container = _buildContainer(task: scheduledTask);
    addTearDown(container.dispose);

    await _pumpTimeline(tester, container, taskTitle: scheduledTask.title);

    expect(find.textContaining('SCHEDULED '), findsOneWidget);
    expect(find.textContaining('OVERDUE SINCE'), findsNothing);
    expect(find.textContaining('Task deadline missed'), findsNothing);
    expect(find.text('Nothing needs action now'), findsOneWidget);
  });

  testWidgets(
    'edit validates title, prevents duplicate actions, and reports success',
    (WidgetTester tester) async {
      final Completer<void> updateCompleter = Completer<void>();
      late _RecordingTaskActions actions;
      final ProviderContainer container = _buildContainer(
        onActionsBuilt: (_RecordingTaskActions value) => actions = value,
        updateCompleter: updateCompleter,
      );
      addTearDown(container.dispose);
      await _pumpTimeline(tester, container);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit task'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('timeline-task-title-field')),
        '   ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      expect(find.text('Enter a task title.'), findsOneWidget);
      expect(actions.updateCalls, 0);

      await tester.enterText(
        find.byKey(const Key('timeline-task-title-field')),
        '  Renamed task  ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(actions.updateCalls, 1);
      expect(actions.updatedId, 'task-managed');
      expect(actions.updatedTitle, 'Renamed task');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Delete'),
            )
            .onPressed,
        isNull,
      );

      updateCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(actions.updateCalls, 1);
      expect(find.text('Task updated.'), findsOneWidget);
    },
  );

  testWidgets('delete requires explicit confirmation and reports success', (
    WidgetTester tester,
  ) async {
    late _RecordingTaskActions actions;
    final ProviderContainer container = _buildContainer(
      onActionsBuilt: (_RecordingTaskActions value) => actions = value,
    );
    addTearDown(container.dispose);
    await _pumpTimeline(tester, container);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete task?'), findsOneWidget);
    expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    expect(actions.deleteCalls, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(actions.deleteCalls, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(actions.deleteCalls, 1);
    expect(actions.deletedId, 'task-managed');
    expect(find.text('Task deleted.'), findsOneWidget);
  });

  testWidgets('edit failure leaves a clear accessible error', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = _buildContainer(
      updateError: StateError('write failed'),
    );
    addTearDown(container.dispose);
    await _pumpTimeline(tester, container);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('timeline-task-title-field')),
      'Renamed task',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Task could not be updated. Refresh and try again.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Task could not be updated. Refresh and try again.',
      ),
      findsOneWidget,
    );
  });
}

ProviderContainer _buildContainer({
  Task? task,
  List<TimelineEventEntity> baseEvents = const <TimelineEventEntity>[],
  bool persistenceCorrupted = false,
  Future<List<Task>> Function(Ref ref)? tasksLoader,
  Set<String> expectedTutorialTaskIds = const <String>{},
  void Function(_TimelineNotifier value)? onTimelineNotifierBuilt,
  void Function(_RecordingTaskActions value)? onActionsBuilt,
  Completer<void>? updateCompleter,
  Object? updateError,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      timelineProvider.overrideWith(() {
        final _TimelineNotifier notifier = _TimelineNotifier(baseEvents);
        onTimelineNotifierBuilt?.call(notifier);
        return notifier;
      }),
      timelinePersistenceCorruptedProvider.overrideWith(
        (Ref ref) => persistenceCorrupted,
      ),
      goalsProvider.overrideWith(_EmptyGoalsNotifier.new),
      adaptiveGuidanceProvider.overrideWith(
        () => _ExpectedGuidanceNotifier(expectedTutorialTaskIds),
      ),
      tasksProvider.overrideWith(
        tasksLoader ?? (Ref ref) async => <Task>[task ?? _managedTask],
      ),
      taskActionsProvider.overrideWith((Ref ref) {
        final _RecordingTaskActions actions = _RecordingTaskActions(
          ref,
          updateCompleter: updateCompleter,
          updateError: updateError,
        );
        onActionsBuilt?.call(actions);
        return actions;
      }),
    ],
  );
  container.read(taskActionsProvider);
  return container;
}

Future<void> _pumpTimelineShell(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const TimelineScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpTimeline(
  WidgetTester tester,
  ProviderContainer container, {
  String taskTitle = 'Managed task',
}) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const TimelineScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.text(taskTitle), findsOneWidget);
}

final Task _managedTask = Task(
  id: 'task-managed',
  title: 'Managed task',
  priority: 3,
  difficulty: 2,
  energyRequired: 2,
  dueDate: DateTime.now(),
);

final TimelineEventEntity _baseEvent = TimelineEventEntity(
  id: 'saved-activity',
  type: TimelineEventType.reflection,
  title: 'Saved Timeline activity',
  detail: 'A valid local event remains visible.',
  timestamp: DateTime.now().subtract(const Duration(hours: 1)),
);

class _RecordingTaskActions extends TaskActions {
  // The superclass positional parameter is private to its library.
  // ignore: use_super_parameters
  _RecordingTaskActions(Ref ref, {this.updateCompleter, this.updateError})
    : super(ref);

  final Completer<void>? updateCompleter;
  final Object? updateError;
  int updateCalls = 0;
  int deleteCalls = 0;
  String? updatedId;
  String? updatedTitle;
  String? deletedId;

  @override
  Future<void> updateTask({required String id, required String title}) async {
    updateCalls += 1;
    updatedId = id;
    updatedTitle = title;
    if (updateError != null) {
      throw updateError!;
    }
    await (updateCompleter?.future ?? Future<void>.value());
  }

  @override
  Future<void> deleteTask(String id) async {
    deleteCalls += 1;
    deletedId = id;
  }
}

class _EmptyGoalsNotifier extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _TimelineNotifier extends TimelineNotifier {
  _TimelineNotifier(this.events);

  final List<TimelineEventEntity> events;
  int persistenceRepairCalls = 0;

  @override
  List<TimelineEventEntity> build() => events;

  @override
  Future<void> preserveAndRepairCorruptedStorage() async {
    persistenceRepairCalls += 1;
  }
}

class _ExpectedGuidanceNotifier extends AdaptiveGuidanceNotifier {
  _ExpectedGuidanceNotifier(this.expectedTaskIds);

  final Set<String> expectedTaskIds;

  @override
  Future<AdaptiveGuidanceState> build() async => AdaptiveGuidanceState(
    milestones: const <GuidanceMilestone, DateTime>{},
    counts: const <GuidanceMilestone, int>{},
    skippedLessons: const <GuidanceLessonId>{},
    completedLessons: const <GuidanceLessonId>{},
    expectedFirstRunCreatorTaskIds: expectedTaskIds,
  );
}
