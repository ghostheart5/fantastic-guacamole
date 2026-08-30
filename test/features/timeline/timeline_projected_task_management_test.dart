import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  void Function(_RecordingTaskActions value)? onActionsBuilt,
  Completer<void>? updateCompleter,
  Object? updateError,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      timelineProvider.overrideWith(_EmptyTimelineNotifier.new),
      goalsProvider.overrideWith(_EmptyGoalsNotifier.new),
      tasksProvider.overrideWith(
        (Ref ref) async => <Task>[task ?? _managedTask],
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

class _EmptyTimelineNotifier extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];
}
