import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/tasks/widgets/task_edit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The optional note and prefilled scheduled time added for Future outcomes.
/// Every other caller passes neither, and must see the dialog exactly as
/// before: no note, and the task's own scheduled time.
void main() {
  final DateTime scheduled = DateTime(2026, 8, 18, 9, 30);

  TaskEntity task() => TaskEntity(
    id: 'task-1',
    title: 'Draft the proposal',
    createdAt: DateTime(2026, 8, 1),
    priority: 3,
    difficulty: 3,
    energyRequired: 3,
    scheduledFor: scheduled,
  );

  Future<List<TaskEditDraft?>> open(
    WidgetTester tester, {
    String? note,
    DateTime? initialScheduledFor,
    bool passNothing = false,
  }) async {
    final List<TaskEditDraft?> results = <TaskEditDraft?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                results.add(
                  passNothing
                      ? await showTaskEditDialog(
                          context: context,
                          editable: task(),
                          goals: const <GoalEntity>[],
                        )
                      : await showTaskEditDialog(
                          context: context,
                          editable: task(),
                          goals: const <GoalEntity>[],
                          note: note,
                          initialScheduledFor: initialScheduledFor,
                        ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('existing callers: no note and the task\'s own scheduled time', (
    WidgetTester tester,
  ) async {
    final results = await open(tester, passNothing: true);
    expect(find.byKey(const Key('task-edit-note')), findsNothing);
    expect(find.textContaining('9:30 AM'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(results.single!.scheduledFor, scheduled);
    expect(results.single!.title, 'Draft the proposal');
  });

  testWidgets('the new parameters default to no note and no prefill', (
    WidgetTester tester,
  ) async {
    final results = await open(tester);
    expect(find.byKey(const Key('task-edit-note')), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(results.single!.scheduledFor, scheduled);
  });

  testWidgets(
    'a note is shown and read out; the prefill is what Save returns',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final DateTime later = scheduled.add(const Duration(days: 1));
      final results = await open(
        tester,
        note: 'From Future outcomes: put off by 1 day',
        initialScheduledFor: later,
      );
      expect(find.byKey(const Key('task-edit-note')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('From Future outcomes: put off by 1 day')),
        findsOneWidget,
      );
      expect(find.textContaining('Aug 19'), findsOneWidget);
      expect(find.textContaining('Aug 18'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(results.single!.scheduledFor, later);
      semantics.dispose();
    },
  );

  testWidgets('Cancel returns nothing, even with a prefill', (
    WidgetTester tester,
  ) async {
    final results = await open(
      tester,
      note: 'From Future outcomes: put off by 1 day',
      initialScheduledFor: scheduled.add(const Duration(days: 1)),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(results.single, isNull);
  });
}
