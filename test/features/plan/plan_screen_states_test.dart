import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/planning/planner_input.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/state/providers/calendar_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loading state displays loader', (WidgetTester tester) async {
    final Completer<List<Task>> completer = Completer<List<Task>>();
    final ProviderContainer container = ProviderContainer(
      overrides: [tasksProvider.overrideWith((Ref ref) => completer.future)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state displays retry action', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith(
          (Ref ref) =>
              Future<List<Task>>.error(StateError('task stream failed')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pump();

    // The error surface must stay human-readable. Asserting on the absence of
    // the exception text is the point: an earlier version interpolated the raw
    // error object into the UI, which leaked stack detail and read as a crash.
    expect(find.textContaining('task stream failed'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
    expect(find.textContaining("couldn't load your plan"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows empty-plan helper when no calendar entries exist', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tasksProvider.overrideWith((Ref ref) async => const <Task>[]),
        calendarServiceProvider.overrideWithValue(_EmptyCalendarService()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('NO PLAN YET'), findsOneWidget);
    expect(
      find.text('Add tasks to generate your daily schedule'),
      findsOneWidget,
    );
  });
}

class _EmptyCalendarService extends CalendarService {
  @override
  List<TimeBlock> generateAdaptivePlan({
    required List<PlannerInput> inputs,
    required double energy,
    DateTime? startTime,
  }) {
    return const <TimeBlock>[];
  }
}
