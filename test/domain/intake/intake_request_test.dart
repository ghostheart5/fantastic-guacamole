import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/domain/intake/intake_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical intake normalizes task-backed routine and note input', () {
    final routine = IntakeRequest.fromRaw(
      title: ' Habit ', description: ' body ', type: 'habit', creatorMode: 'tasks',
      priority: 2, scheduledFor: null, recurrenceRule: RecurrenceRule.none,
    );
    final note = IntakeRequest.fromRaw(
      title: 'Note', description: null, type: 'memo', creatorMode: 'tasks',
      priority: 5, scheduledFor: null, recurrenceRule: RecurrenceRule.none,
    );
    expect(routine.kind, IntakeKind.routine);
    expect(routine.taskKind, 'habit');
    expect(routine.resolvedRecurrence, RecurrenceRule.daily);
    expect(note.kind, IntakeKind.note);
    expect(note.resolvedPriority, 1);
  });
  test('canonical intake resolves modes and validates invariants', () {
    final goal = IntakeRequest.fromRaw(
      title: 'Goal', description: null, type: 'task', creatorMode: 'goals',
      priority: 1, scheduledFor: null, recurrenceRule: RecurrenceRule.none,
    );
    expect(goal.kind, IntakeKind.goal);
    expect(goal.resolvedPriority, 4);
    final invalid = IntakeRequest.fromRaw(
      title: '', description: null, type: 'task', creatorMode: 'tasks',
      priority: 6, scheduledFor: null, recurrenceRule: RecurrenceRule.none,
    );
    expect(invalid.validate, throwsStateError);
  });
}
