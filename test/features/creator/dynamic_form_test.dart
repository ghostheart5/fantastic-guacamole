import 'package:fantastic_guacamole/features/creator/widgets/dynamic_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
