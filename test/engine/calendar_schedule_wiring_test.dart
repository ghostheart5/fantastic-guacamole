import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/planning/calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adaptive plan keeps tasks on their selected calendar day', () {
    final DateTime now = DateTime(2026, 7, 6, 10);
    final DateTime scheduled = DateTime(2026, 7, 8);

    final blocks = CalendarService().generateAdaptivePlan(
      tasks: <Task>[
        Task(
          id: 'future-task',
          title: 'Future task',
          priority: 3,
          difficulty: 2,
          energyRequired: 2,
          scheduledFor: scheduled,
        ),
      ],
      energy: 0.5,
      startTime: now,
    );

    expect(blocks, hasLength(1));
    expect(blocks.single.start.year, scheduled.year);
    expect(blocks.single.start.month, scheduled.month);
    expect(blocks.single.start.day, scheduled.day);
    expect(blocks.single.start.hour, 9);
  });

  test('adaptive plan compares energy on the same normalized scale', () {
    final blocks = CalendarService().generateAdaptivePlan(
      tasks: const <Task>[
        Task(
          id: 'high-energy',
          title: 'High energy',
          priority: 3,
          difficulty: 2,
          energyRequired: 5,
        ),
        Task(
          id: 'low-energy',
          title: 'Low energy',
          priority: 3,
          difficulty: 2,
          energyRequired: 1,
        ),
      ],
      energy: 0.2,
      startTime: DateTime(2026, 7, 6, 10),
    );

    expect(blocks.first.taskId, 'low-energy');
  });
}
