import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoteEntity round-trips canonical Note fields only', () {
    final NoteEntity note = NoteEntity(
      id: 'note-1',
      title: 'A note',
      body: 'Private context',
      createdAt: DateTime.utc(2026, 8, 15, 10),
      updatedAt: DateTime.utc(2026, 8, 15, 11),
      userId: 'account-a',
      isArchived: true,
      goalId: 'goal-1',
      taskId: 'task-1',
      habitId: 'habit-1',
    );

    final Map<String, dynamic> json = note.toJson();
    final NoteEntity restored = NoteEntity.fromJson(json);

    expect(restored.id, note.id);
    expect(restored.title, note.title);
    expect(restored.body, note.body);
    expect(restored.createdAt, note.createdAt);
    expect(restored.updatedAt, note.updatedAt);
    expect(restored.isArchived, isTrue);
    expect(restored.goalId, 'goal-1');
    expect(restored.taskId, 'task-1');
    expect(restored.habitId, 'habit-1');
    expect(json.keys, isNot(contains('priority')));
    expect(json.keys, isNot(contains('dueDate')));
    expect(json.keys, isNot(contains('recurrence')));
    expect(json.keys, isNot(contains('kind')));
    expect(json.keys, isNot(contains('completed')));
  });
}
