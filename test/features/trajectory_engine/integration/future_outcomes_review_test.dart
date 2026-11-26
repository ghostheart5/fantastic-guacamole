import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/future_outcomes_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// "Review" on Future outcomes opens the task the chosen option is about.
/// Nothing is written without the person's own Save or Done, and never in
/// another account.
void main() {
  final AccountStorageScope accountA = AccountStorageScope.authenticated(
    'review-a',
  );
  final AccountStorageScope accountB = AccountStorageScope.authenticated(
    'review-b',
  );

  testWidgets('delay: the edit dialog for the task, its due-only time moved '
      'by the option\'s delay from the estimate time, and the note', (
    WidgetTester tester,
  ) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const Key('task-edit-note')), findsOneWidget);
    expect(
      find.text('From Future outcomes: put off by 2 days'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Draft the proposal',
    );
    // The engine moves a task with no scheduled time from the estimate's
    // time (trajectoryFixtureNow) by the option's delay (2 days here).
    final DateTime expected = trajectoryFixtureNow.add(const Duration(days: 2));
    expect(
      find.textContaining(_dateText(tester, expected.toLocal())),
      findsOneWidget,
    );
    expect(f.actions.log, isEmpty);
  });

  testWidgets('delay: a scheduled task moves from its scheduled time', (
    WidgetTester tester,
  ) async {
    final DateTime scheduled = DateTime(2026, 8, 17, 9, 30);
    final _Fixture f = await _pump(
      tester,
      accountA,
      tasks: <Task>[
        _taskA(scheduledFor: scheduled),
        _taskD(),
      ],
    );
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');
    await tester.tap(find.text('Save'));
    await settleFutureOutcomes(tester);

    expect(f.actions.log, <String>['update:task-a']);
    expect(f.actions.scheduled.single, scheduled.add(const Duration(days: 2)));
  });

  testWidgets('delay: Cancel writes nothing; Save writes that task only, '
      'with the new time, and the next Review starts from it', (
    WidgetTester tester,
  ) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');
    await tester.tap(find.text('Cancel'));
    await settleFutureOutcomes(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.actions.log, isEmpty);

    await _review(tester, 'Edit this task');
    await tester.tap(find.text('Save'));
    await settleFutureOutcomes(tester);
    final DateTime moved = trajectoryFixtureNow.add(const Duration(days: 2));
    expect(f.actions.log, <String>['update:task-a']);
    expect(f.actions.scheduled.single!.isAtSameMomentAs(moved), isTrue);
    expect(f.actions.titles.single, 'Draft the proposal');
    expect(f.engineRefreshes, 0);

    // The saved time is what the task has now: the next Review moves it on
    // from there, not from the old time.
    await _review(tester, 'Edit this task');
    expect(
      find.textContaining(
        _dateText(tester, moved.add(const Duration(days: 2)).toLocal()),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settleFutureOutcomes(tester);
    expect(f.actions.log, <String>['update:task-a']);
  });

  testWidgets('complete: a confirm dialog naming the task; Cancel does '
      'nothing; Done completes it once', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Complete Draft the proposal');
    await _review(tester, 'Mark done…');
    expect(find.text('Mark "Draft the proposal" done?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settleFutureOutcomes(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.actions.log, isEmpty);

    await _review(tester, 'Mark done…');
    await tester.tap(find.text('Done'));
    await settleFutureOutcomes(tester);
    expect(f.actions.log, <String>['complete:task-a']);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('complete A, the planner then shows B: the card for B does '
      'not say "picked"', (WidgetTester tester) async {
    final _Fixture f = await _pump(
      tester,
      accountA,
      options: const <String>['maintain', 'complete', 'reduce'],
      // Below the recommendation gate, so no option is "Recommended" and the
      // label says whether the person picked it.
      observationCount: 4,
    );
    final Finder selected = find.byKey(const Key('future-outcomes-selected'));
    await _choose(tester, 'Complete Draft the proposal');
    expect(
      find.descendant(of: selected, matching: find.text('Option you picked')),
      findsOneWidget,
    );
    await _review(tester, 'Mark done…');
    await tester.tap(find.text('Done'));
    await settleFutureOutcomes(tester);
    expect(f.actions.log, <String>['complete:task-a']);
    // A leaves the plan; the planner's options now finish B instead.
    f.container.read(_options.notifier).set(const <String>[
      'maintain',
      'completeB',
      'reduce',
    ]);
    await settleFutureOutcomes(tester);
    await _reveal(tester, selected);
    expect(
      find.descendant(
        of: selected,
        matching: find.text('Complete Prepare the review'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(of: selected, matching: find.text('Option you picked')),
      findsNothing,
    );
    expect(
      find.descendant(of: selected, matching: find.text('Option shown')),
      findsOneWidget,
    );
  });

  testWidgets('a range change keeps the picked option and its label', (
    WidgetTester tester,
  ) async {
    await _pump(tester, accountA, observationCount: 4);
    final Finder selected = find.byKey(const Key('future-outcomes-selected'));
    await _choose(tester, 'Complete Draft the proposal');
    await tapFutureOutcomes(tester, find.text('30 days'));
    await _reveal(tester, selected);
    expect(
      find.descendant(of: selected, matching: find.text('Option you picked')),
      findsOneWidget,
    );
  });

  testWidgets('a saved edit asks about reminders, as the other task editors '
      'do; Cancel does not', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');
    await tester.tap(find.text('Cancel'));
    await settleFutureOutcomes(tester);
    expect(f.reminderAsks, isEmpty);
    await _review(tester, 'Edit this task');
    await tester.tap(find.text('Save'));
    await settleFutureOutcomes(tester);
    expect(f.actions.log, <String>['update:task-a']);
    expect(f.reminderAsks, hasLength(1));
  });

  testWidgets('the account switches and Save is tapped before the next frame: '
      'nothing is written', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');
    expect(find.byType(AlertDialog), findsOneWidget);
    // No frame between the switch and the tap.
    f.container.read(_scope.notifier).set(accountB);
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await settleFutureOutcomes(tester);
    await settleFutureOutcomes(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.actions.log, isEmpty);
    expect(f.reminderAsks, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('es')]) {
    final bool es = locale.languageCode == 'es';
    testWidgets('${locale.languageCode}: tasks that cannot be read: a plain '
        'message, no dialog, nothing written', (WidgetTester tester) async {
      final _Fixture f = await _pump(
        tester,
        accountA,
        locale: locale,
        tasksUnreadable: true,
      );
      await _choose(tester, es ? 'Aplazar el hito' : 'Delay the milestone');
      await _review(tester, es ? 'Editar esta tarea' : 'Edit this task');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(
          es
              ? 'No se pudieron leer tus tareas. Inténtalo de nuevo.'
              : 'Your tasks could not be read. Try again.',
        ),
        findsOneWidget,
      );
      expect(f.actions.log, isEmpty);
    });

    testWidgets('${locale.languageCode}: a save that fails says so', (
      WidgetTester tester,
    ) async {
      final _Fixture f = await _pump(tester, accountA, locale: locale);
      f.actions.fail = true;
      await _choose(tester, es ? 'Aplazar el hito' : 'Delay the milestone');
      await _review(tester, es ? 'Editar esta tarea' : 'Edit this task');
      await tester.tap(find.text(es ? 'Guardar' : 'Save'));
      await settleFutureOutcomes(tester);
      expect(
        find.text(
          es
              ? 'No se pudieron guardar los cambios. Inténtalo de nuevo.'
              : 'Could not save your changes. Please try again.',
        ),
        findsOneWidget,
      );
      expect(f.reminderAsks, isEmpty);
    });

    testWidgets('${locale.languageCode}: Done says it is recorded; a failed '
        'Done says so', (WidgetTester tester) async {
      final _Fixture f = await _pump(tester, accountA, locale: locale);
      final String complete = es
          ? 'Completar Draft the proposal'
          : 'Complete Draft the proposal';
      final String markDone = es ? 'Marcar como hecha…' : 'Mark done…';
      final String done = es ? 'Hecha' : 'Done';
      await _choose(tester, complete);
      await _review(tester, markDone);
      await tester.tap(find.text(done));
      await settleFutureOutcomes(tester);
      expect(
        find.text(
          es
              ? 'Completada. Tu progreso quedó registrado.'
              : 'Completed. Your progress is recorded.',
        ),
        findsOneWidget,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(TrajectoryEngineScreen)),
      ).removeCurrentSnackBar();
      await settleFutureOutcomes(tester);

      f.actions.fail = true;
      await _review(tester, markDone);
      await tester.tap(find.text(done));
      await settleFutureOutcomes(tester);
      expect(
        find.text(
          es
              ? 'No se pudo completar la tarea. Inténtalo de nuevo.'
              : 'Could not complete this task. Please try again.',
        ),
        findsOneWidget,
      );
      expect(f.actions.log, <String>['complete:task-a']);
    });
  }

  testWidgets('reduce: the edit dialog for its task with the note and no '
      'change made for the person', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Reduce lower-priority scope');
    await _review(tester, 'Edit this task');
    expect(
      find.text('From Future outcomes: Reduce lower-priority scope'),
      findsOneWidget,
    );
    expect(find.text('No scheduled time'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settleFutureOutcomes(tester);
    expect(f.actions.log, <String>['update:task-d']);
    expect(f.actions.scheduled.single, isNull);
    expect(f.actions.titles.single, 'Tidy the inbox');
  });

  testWidgets('recover: the edit dialog for its task with the note', (
    WidgetTester tester,
  ) async {
    final _Fixture f = await _pump(
      tester,
      accountA,
      options: const <String>['maintain', 'recover'],
    );
    await _choose(tester, 'Recover Prepare the review');
    await _review(tester, 'Edit this task');
    expect(
      find.text('From Future outcomes: Recover Prepare the review'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'Prepare the review',
    );
    await tester.tap(find.text('Cancel'));
    await settleFutureOutcomes(tester);
    expect(f.actions.log, isEmpty);
  });

  for (final (Locale locale, Map<String, String> labels)
      in <(Locale, Map<String, String>)>[
        (
          const Locale('en'),
          <String, String>{
            'Keep going as you are': 'Review on Schedule',
            'Keep the suggested plan': 'Open Choose a step',
            'Complete Draft the proposal': 'Mark done…',
            'Delay the milestone': 'Edit this task',
            'Reduce lower-priority scope': 'Edit this task',
            'Recover Prepare the review': 'Edit this task',
          },
        ),
        (
          const Locale('es'),
          <String, String>{
            'Seguir como vas': 'Revisar en agenda',
            'Proteger el camino de Elegir un paso': 'Abrir Elegir un paso',
            'Completar Draft the proposal': 'Marcar como hecha…',
            'Aplazar el hito': 'Editar esta tarea',
            'Reducir el alcance de menor prioridad': 'Editar esta tarea',
            'Recuperar Prepare the review': 'Editar esta tarea',
          },
        ),
      ]) {
    testWidgets('${locale.languageCode}: each button says what opens', (
      WidgetTester tester,
    ) async {
      final Set<String> checked = <String>{};
      // Only three options are listed at a time, so two sets.
      for (final List<String> options in <List<String>>[
        <String>['maintain', 'planner', 'complete'],
        <String>['delay', 'reduce', 'recover'],
      ]) {
        // A fresh provider scope for each set of options.
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, accountA, locale: locale, options: options);
        for (final MapEntry<String, String> entry in labels.entries) {
          if (find.text(entry.key).evaluate().isEmpty) continue;
          await _choose(tester, entry.key);
          final Finder button = find.descendant(
            of: find.byKey(const Key('future-outcomes-selected')),
            matching: find.byType(FilledButton),
          );
          expect(
            find.descendant(of: button, matching: find.text(entry.value)),
            findsOneWidget,
            reason: entry.key,
          );
          checked.add(entry.key);
        }
      }
      expect(checked, labels.keys.toSet());
      // The planning summary button names its own destination.
      await tapFutureOutcomes(
        tester,
        find.text(
          locale.languageCode == 'es'
              ? 'En qué se basa'
              : 'What this is based on',
        ),
      );
      await revealFutureOutcomes(
        tester,
        find.byKey(const Key('future-outcomes-planning-summary')),
      );
      final Finder summaryButton = find.descendant(
        of: find.byKey(const Key('future-outcomes-planning-summary')),
        matching: find.byType(OutlinedButton),
      );
      expect(
        find.descendant(
          of: summaryButton,
          matching: find.text(
            locale.languageCode == 'es' ? 'Abrir Mi plan' : 'Open My plan',
          ),
        ),
        findsOneWidget,
      );
      // The summary's own action is labelled "Review on Schedule" by its
      // producer but opens My plan, so the button never borrows that wording.
      expect(
        futureOutcomesDecision(firstSummary: true).decision.actionIntent.label,
        'Review on Schedule',
      );
      expect(
        find.descendant(
          of: summaryButton,
          matching: find.text(
            locale.languageCode == 'es'
                ? 'Revisar en agenda'
                : 'Review on Schedule',
          ),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('the planner option opens Choose a step', (
    WidgetTester tester,
  ) async {
    final _Fixture f = await _pump(
      tester,
      accountA,
      options: const <String>['maintain', 'planner'],
    );
    await _choose(tester, 'Keep the suggested plan');
    await _review(tester, 'Open Choose a step');
    expect(f.container.read(appFlowProvider), AppView.smartPlanner);
    expect(f.actions.log, isEmpty);
  });

  testWidgets('a task that no longer exists: a plain message, then My plan; '
      'nothing written', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA, tasks: <Task>[_taskD()]);
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text(
        'That task is no longer in your plan. It may have been finished or deleted.',
      ),
      findsOneWidget,
    );
    expect(f.container.read(appFlowProvider), AppView.timeline);
    expect(f.actions.log, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a finished task: no confirm dialog, the message, nothing written',
    (WidgetTester tester) async {
      final _Fixture f = await _pump(tester, accountA, tasks: <Task>[_taskD()]);
      await _choose(tester, 'Complete Draft the proposal');
      await _review(tester, 'Mark done…');
      expect(find.byType(AlertDialog), findsNothing);
      expect(f.container.read(appFlowProvider), AppView.timeline);
      expect(f.actions.log, isEmpty);
    },
  );

  testWidgets('account switch while the edit dialog is open: it closes and '
      'nothing is written in either account', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Delay the milestone');
    await _review(tester, 'Edit this task');
    expect(find.byType(AlertDialog), findsOneWidget);
    f.container.read(_scope.notifier).set(accountB);
    // The new scope reaches the screen on the next frame; then the dialog
    // plays its closing animation.
    await settleFutureOutcomes(tester);
    await settleFutureOutcomes(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.actions.log, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new sign-in while the confirm dialog is open: it closes and '
      'nothing is completed', (WidgetTester tester) async {
    final _Fixture f = await _pump(tester, accountA);
    await _choose(tester, 'Complete Draft the proposal');
    await _review(tester, 'Mark done…');
    expect(find.byType(AlertDialog), findsOneWidget);
    final AuthSessionBoundaryNotifier boundary = f.container.read(
      authSessionBoundaryProvider.notifier,
    );
    boundary.complete(
      boundary.begin(userId: 'review-a', isTransitioning: true),
    );
    await settleFutureOutcomes(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.actions.log, isEmpty);
  });

  group('accessibility', () {
    testWidgets('the confirm dialog and the note are read out; 48 dp targets', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pump(tester, accountA);
      await _choose(tester, 'Complete Draft the proposal');
      await _review(tester, 'Mark done…');
      expect(
        find.bySemanticsLabel(RegExp('Mark "Draft the proposal" done\\?')),
        findsWidgets,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await tester.tap(find.text('Cancel'));
      await settleFutureOutcomes(tester);

      await _choose(tester, 'Delay the milestone');
      await _review(tester, 'Edit this task');
      expect(
        find.bySemanticsLabel(
          RegExp('From Future outcomes: put off by 2 days'),
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });

    for (final Locale locale in <Locale>[
      const Locale('en'),
      const Locale('es'),
    ]) {
      testWidgets('${locale.languageCode}: no overflow at 2x on 320 dp', (
        WidgetTester tester,
      ) async {
        final bool es = locale.languageCode == 'es';
        await _pump(
          tester,
          accountA,
          locale: locale,
          size: const Size(320, 640),
          textScale: 2,
        );
        await _choose(
          tester,
          es ? 'Completar Draft the proposal' : 'Complete Draft the proposal',
        );
        await _review(tester, es ? 'Marcar como hecha…' : 'Mark done…');
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
        _expectInside(tester, find.byType(AlertDialog), 320);
        await tester.tap(find.text(es ? 'Cancelar' : 'Cancel'));
        await settleFutureOutcomes(tester);

        await _choose(tester, es ? 'Aplazar el hito' : 'Delay the milestone');
        // Nothing in the edit dialog overflows, the priority menu included.
        await _review(tester, es ? 'Editar esta tarea' : 'Edit this task');
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsOneWidget);
        final Rect priority = tester.getRect(
          find.byKey(const Key('timeline-task-priority-field')),
        );
        expect(priority.left, greaterThanOrEqualTo(0));
        expect(priority.right, lessThanOrEqualTo(320));
        final Finder note = find.text(
          es
              ? 'Desde Resultados futuros: aplazar 2 días'
              : 'From Future outcomes: put off by 2 days',
        );
        expect(note, findsOneWidget);
        _expectInside(tester, note, 320);
      });
    }
  });
}

final _scope =
    NotifierProvider<
      FutureOutcomesValue<AccountStorageScope>,
      AccountStorageScope
    >(
      () => FutureOutcomesValue<AccountStorageScope>(
        AccountStorageScope.authenticated('review-a'),
      ),
    );

class _Fixture {
  _Fixture(this.container, this.actions, this.refreshes, this.reminderAsks);
  final ProviderContainer container;
  final _RecordingActions actions;
  final List<int> refreshes;

  /// Each time the screen asked whether a saved task needs reminders (the
  /// same step Today and the other task editors take after a save).
  final List<int> reminderAsks;
  int get engineRefreshes => refreshes.length;
}

/// Counts the reminder question after a save. Reading the preferences fails
/// on purpose, so no permission prompt follows in the test.
class _CountingSettingsActions extends SettingsUiActions {
  _CountingSettingsActions(super.ref, this.asks);
  final List<int> asks;
  @override
  ReminderOrchestratorPrefs loadAdvancedReminderPrefs() {
    asks.add(1);
    throw StateError('not needed in this test');
  }
}

Task _taskA({DateTime? scheduledFor}) => Task(
  id: 'task-a',
  title: 'Draft the proposal',
  priority: 4,
  difficulty: 3,
  energyRequired: 3,
  estimatedDuration: const Duration(minutes: 60),
  dueDate: scheduledFor == null
      ? trajectoryFixtureNow.add(const Duration(days: 3)).toLocal()
      : null,
  scheduledFor: scheduledFor,
);

Task _taskB() => Task(
  id: 'task-b',
  title: 'Prepare the review',
  priority: 3,
  difficulty: 3,
  energyRequired: 3,
  estimatedDuration: const Duration(minutes: 120),
);

Task _taskD() => Task(
  id: 'task-d',
  title: 'Tidy the inbox',
  priority: 1,
  difficulty: 2,
  energyRequired: 2,
);

final _tasks = NotifierProvider<FutureOutcomesValue<List<Task>>, List<Task>>(
  () => FutureOutcomesValue<List<Task>>(<Task>[]),
);

final _options =
    NotifierProvider<FutureOutcomesValue<List<String>>, List<String>>(
      () => FutureOutcomesValue<List<String>>(<String>[]),
    );

/// Records writes instead of touching storage; a saved time becomes the
/// task's time, as the repository would make it.
class _RecordingActions extends TaskActions {
  _RecordingActions(this._own) : super(_own);

  final Ref _own;
  final List<String> log = <String>[];
  final List<DateTime?> scheduled = <DateTime?>[];
  final List<String> titles = <String>[];

  /// When true every write fails, as a storage error would.
  bool fail = false;

  @override
  Future<void> updateTaskDetails({
    required String id,
    required String title,
    String? description,
    int? priority,
    Duration? estimatedDuration,
    DateTime? scheduledFor,
    DateTime? dueDate,
    String? goalId,
    bool clearDescription = false,
    bool clearEstimatedDuration = false,
    bool clearScheduledFor = false,
    bool clearDueDate = false,
    bool clearGoalId = false,
  }) async {
    if (fail) throw StateError('save failed');
    log.add('update:$id');
    scheduled.add(clearScheduledFor ? null : scheduledFor);
    titles.add(title);
    final FutureOutcomesValue<List<Task>> tasks = _own.read(_tasks.notifier);
    tasks.set(<Task>[
      for (final Task task in _own.read(_tasks))
        if (task.id == id)
          Task(
            id: task.id,
            title: title,
            priority: task.priority,
            difficulty: task.difficulty,
            energyRequired: task.energyRequired,
            estimatedDuration: task.estimatedDuration,
            dueDate: clearDueDate ? null : dueDate,
            scheduledFor: clearScheduledFor ? null : scheduledFor,
          )
        else
          task,
    ]);
  }

  @override
  Future<void> completeTask(String id, {bool notify = true}) async {
    if (fail) throw StateError('complete failed');
    log.add('complete:$id');
  }
}

class _NoGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _ReadyBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'review-a',
    isTransitioning: false,
    isStorageReady: true,
  );
}

class _CountingEngineActions extends TrajectoryEngineActions {
  _CountingEngineActions(super.ref, this.calls);
  final List<int> calls;
  @override
  void refresh() => calls.add(1);
}

Future<_Fixture> _pump(
  WidgetTester tester,
  AccountStorageScope scope, {
  List<Task>? tasks,
  Locale locale = const Locale('en'),
  Size size = const Size(900, 2400),
  double textScale = 1,
  List<String> options = const <String>['delay', 'complete', 'reduce'],
  int observationCount = 12,
  bool tasksUnreadable = false,
}) async {
  final List<int> refreshes = <int>[];
  final List<int> reminderAsks = <int>[];
  late _RecordingActions actions;
  final ProviderContainer container = await pumpFutureOutcomes(
    tester,
    locale: locale,
    size: size,
    textScale: textScale,
    defaultModel: false,
    extraOverrides: [
      // The options follow [_options], so a test can change them while the
      // screen is shown (as the planner does after a task is finished).
      _options.overrideWith(() => FutureOutcomesValue<List<String>>(options)),
      trajectoryEngineModelProvider.overrideWith((Ref ref) {
        final int days = ref.watch(trajectoryHorizonDaysProvider);
        return futureOutcomesModel(
          days: days,
          comparison: _comparison(
            days,
            scope.v2Namespace!,
            ref.watch(_options),
            observationCount: observationCount,
          ),
          decision: futureOutcomesDecision(firstSummary: true),
        );
      }),
      _scope.overrideWith(
        () => FutureOutcomesValue<AccountStorageScope>(scope),
      ),
      accountStorageScopeProvider.overrideWith((Ref ref) => ref.watch(_scope)),
      authSessionBoundaryProvider.overrideWith(_ReadyBoundary.new),
      _tasks.overrideWith(
        () => FutureOutcomesValue<List<Task>>(
          tasks ?? <Task>[_taskA(), _taskB(), _taskD()],
        ),
      ),
      allTasksProvider.overrideWith((Ref ref) async {
        final List<Task> tasks = ref.watch(_tasks);
        if (tasksUnreadable) throw StateError('tasks could not be read');
        return tasks;
      }),
      settingsUiActionsProvider.overrideWith(
        (Ref ref) => _CountingSettingsActions(ref, reminderAsks),
      ),
      goalsProvider.overrideWith(_NoGoals.new),
      taskActionsProvider.overrideWith((Ref ref) {
        actions = _RecordingActions(ref);
        return actions;
      }),
      trajectoryEngineActionsProvider.overrideWith(
        (Ref ref) => _CountingEngineActions(ref, refreshes),
      ),
    ],
  );
  container.read(taskActionsProvider);
  return _Fixture(container, actions, refreshes, reminderAsks);
}

/// The harness's options (same ids, titles and subject tasks) plus a
/// recover option, keeping only [ids]: the screen lists three at a time.
TrajectoryComparison _comparison(
  int days,
  String accountScope,
  List<String> ids, {
  int observationCount = 12,
}) {
  final Duration horizon = Duration(days: days);
  final TrajectoryBaseline baseline = futureOutcomesBaseline(
    days: days,
    accountScope: accountScope,
    observationCount: observationCount,
  );
  final Map<String, TrajectoryIntervention> all =
      <String, TrajectoryIntervention>{
        for (final TrajectoryScenarioOutcome outcome
            in futureOutcomesComparison(
              days: days,
              baseline: baseline,
            ).outcomes)
          outcome.intervention.id: outcome.intervention,
      };
  final Map<String, String> byShortId = <String, String>{
    'maintain': 'maintain',
    'planner': 'planner',
    'complete': 'complete-task-a',
    'reduce': 'remove-task-d',
    'delay': 'delay-task-a',
  };
  return const FutureConsequenceEngine().compare(
    baseline: baseline,
    generatedAt: trajectoryFixtureNow,
    interventions: <TrajectoryIntervention>[
      for (final String id in ids)
        if (id == 'completeB')
          TrajectoryIntervention(
            id: 'complete-task-b',
            type: TrajectoryInterventionType.completeTask,
            title: 'Complete Prepare the review',
            horizon: horizon,
            description:
                'Model this commitment as completed, then compare capacity, risk, goal timing, and progress consequences.',
            subjectId: 'task-b',
          )
        else if (id == 'recover')
          TrajectoryIntervention(
            id: 'recover-task-b',
            type: TrajectoryInterventionType.recoverCommitment,
            title: 'Recover Prepare the review',
            horizon: horizon,
            description:
                'Apply the task-specific deadline/capacity recovery recommendation.',
            subjectId: 'task-b',
          )
        else
          all[byShortId[id]]!,
    ],
  );
}

/// Picks the option card titled [title] in the Options section.
Future<void> _choose(WidgetTester tester, String title) async {
  final Finder card = find.text(title);
  await _reveal(tester, card);
  await tester.tap(card.hitTestable().first);
  await settleFutureOutcomes(tester);
}

/// Taps the selected option's main button, labelled [label].
Future<void> _review(WidgetTester tester, String label) async {
  final Finder button = find.descendant(
    of: find.byKey(const Key('future-outcomes-selected')),
    matching: find.widgetWithText(FilledButton, label),
  );
  await _reveal(tester, button);
  await tester.tap(button);
  await settleFutureOutcomes(tester);
}

/// Scrolls the page (the vertical list, whatever the width) until [finder]
/// is built, then into view.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final Finder page = find
      .byWidgetPredicate(
        (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .first;
  for (int step = 0; step < 80 && finder.evaluate().isEmpty; step++) {
    await tester.drag(page, const Offset(0, -200));
    await tester.pump();
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

/// [finder] lies within the screen width and its text is never clipped.
void _expectInside(WidgetTester tester, Finder finder, double width) {
  final Rect rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(width));
  for (final RenderParagraph paragraph
      in tester
          .renderObjectList(
            find.descendant(
              of: finder,
              matching: find.byType(RichText),
              matchRoot: true,
            ),
          )
          .whereType<RenderParagraph>()) {
    expect(paragraph.didExceedMaxLines, isFalse);
  }
}

String _dateText(WidgetTester tester, DateTime local) =>
    MaterialLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    ).formatMediumDate(local);
