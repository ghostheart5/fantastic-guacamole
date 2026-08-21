import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    await tester.ensureVisible(find.text('FORGE TASK'));
    await tester.tap(find.text('FORGE TASK'));
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
    bool typeChosen = false;
    bool priorityChosen = false;
    bool submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicForm(
              guidedFirstTask: true,
              onTitleValidityChanged: (bool value) => titleReady = value,
              onTypeChosen: () => typeChosen = true,
              onPriorityChosen: () => priorityChosen = true,
              onSubmit: (_) async => submitted = true,
            ),
          ),
        ),
      ),
    );

    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Prepare the first launch');
    await tester.tap(find.text('TASK'));
    await tester.tap(find.bySemanticsLabel('Set priority level 4'));
    await tester.ensureVisible(find.text('FORGE TASK'));
    await tester.tap(find.text('FORGE TASK'));
    await tester.pump();

    expect(titleReady, isTrue);
    expect(typeChosen, isTrue);
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
    await tester.tap(find.text('FORGE TASK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('The task could not be saved. Your entry is still here—retry.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(titleField).controller?.text,
      'Keep this task',
    );
  });
}
