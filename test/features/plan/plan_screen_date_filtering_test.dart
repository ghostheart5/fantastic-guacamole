import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'a task scheduled last month does not appear on this week\'s same '
    'weekday, a task scheduled for the selected date does appear, and a '
    'daily recurring task generates a valid occurrence for today',
    (WidgetTester tester) async {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day, 9);
      // Five weeks back guarantees the same weekday as today while being
      // unambiguously outside the current calendar week.
      final DateTime fiveWeeksAgo = today.subtract(const Duration(days: 35));

      final Task staleTask = Task(
        id: 'stale-task',
        title: 'Stale scheduled task',
        priority: 5,
        difficulty: 2,
        energyRequired: 2,
        scheduledFor: fiveWeeksAgo,
      );
      final Task todayTask = Task(
        id: 'today-task',
        title: 'Today scheduled task',
        priority: 4,
        difficulty: 2,
        energyRequired: 2,
        scheduledFor: today,
      );
      final Task dailyTask = const Task(
        id: 'daily-task',
        title: 'Daily recurring task',
        priority: 3,
        difficulty: 1,
        energyRequired: 2,
        recurrenceRule: RecurrenceRule.daily,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: [
          tasksProvider.overrideWith(
            (Ref ref) async => <Task>[staleTask, todayTask, dailyTask],
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
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Stale scheduled task'), findsNothing);
      expect(find.text('Today scheduled task'), findsOneWidget);
      expect(find.text('Daily recurring task'), findsOneWidget);
    },
  );
}
