import 'package:fantastic_guacamole/features/tasks/widgets/task_card.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap routes to smart coach and complete action dispatches callback', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    TaskView? completed;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TaskCard(
              task: const TaskView(
                id: 'task-1',
                title: 'Stabilize release path',
                priority: 4,
                difficulty: 3,
                energyRequired: 3,
              ),
              onComplete: (TaskView task) async {
                completed = task;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Stabilize release path'), findsOneWidget);

    await tester.tap(find.text('Stabilize release path'));
    await tester.pump();
    expect(container.read(appFlowProvider), AppView.smartCoach);

    await tester.tap(find.byTooltip('Complete task'));
    await tester.pump();

    expect(completed, isNotNull);
    expect(completed!.id, 'task-1');
  });
}
