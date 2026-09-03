import 'package:fantastic_guacamole/data/adapters/note_timeline_adapter.dart';
import 'package:fantastic_guacamole/data/storage/adapters/goal_entity_adapter.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  test('goal adapter reads current records in the order they are written', () {
    final DateTime createdAt = DateTime.utc(2026, 9, 1, 8);
    final DateTime targetDate = DateTime.utc(2026, 9, 8, 8);
    final DateTime completedAt = DateTime.utc(2026, 9, 3, 8);
    final GoalEntity source = GoalEntity(
      id: 'goal-1',
      title: 'Close Priority 7',
      createdAt: createdAt,
      description: 'Verified evidence',
      targetDate: targetDate,
      colorHex: 0xFF123456,
      completedAt: completedAt,
    );
    final _TokenWriter writer = _TokenWriter();
    final GoalEntityAdapter adapter = GoalEntityAdapter();

    adapter.write(writer, source);
    final GoalEntity restored = adapter.read(_TokenReader(writer.values));

    expect(adapter.typeId, 101);
    expect(restored.id, source.id);
    expect(restored.title, source.title);
    expect(restored.createdAt.toUtc(), createdAt);
    expect(restored.description, source.description);
    expect(restored.targetDate, targetDate);
    expect(restored.colorHex, source.colorHex);
    expect(restored.completedAt, completedAt);
  });

  test('goal adapter preserves legacy records without completion state', () {
    final DateTime createdAt = DateTime.utc(2026, 8, 1);
    final GoalEntity restored = GoalEntityAdapter().read(
      _TokenReader(<Object?>[
        'legacy-goal',
        'Legacy goal',
        createdAt.millisecondsSinceEpoch,
        null,
        null,
        0xFF654321,
      ]),
    );

    expect(restored.id, 'legacy-goal');
    expect(restored.createdAt.toUtc(), createdAt);
    expect(restored.completedAt, isNull);
    expect(restored.isCompleted, isFalse);
  });

  test(
    'note timeline adapter records each mutation once with provenance',
    () async {
      final DateTime updatedAt = DateTime.utc(2026, 9, 3, 11, 30);
      final NoteEntity note = NoteEntity(
        id: 'note-1',
        title: 'Release evidence',
        body: 'Priority 7 gates',
        createdAt: updatedAt.subtract(const Duration(hours: 1)),
        updatedAt: updatedAt,
      );
      final _TimelineRepository timeline = _TimelineRepository();
      final NoteTimelineAdapter adapter = NoteTimelineAdapter(timeline);

      for (final NoteTimelineMutation mutation in NoteTimelineMutation.values) {
        await adapter.record(note, mutation);
        await adapter.record(note, mutation);
      }

      expect(timeline.events, hasLength(4));
      expect(
        timeline.events.map((TimelineEventEntity event) => event.type),
        <TimelineEventType>[
          TimelineEventType.noteCreated,
          TimelineEventType.noteUpdated,
          TimelineEventType.noteArchived,
          TimelineEventType.noteDeleted,
        ],
      );
      expect(
        timeline.events.map((TimelineEventEntity event) => event.title),
        <String>[
          'Note Created',
          'Note Updated',
          'Note Archived',
          'Note Deleted',
        ],
      );
      for (final TimelineEventEntity event in timeline.events) {
        expect(event.detail, note.title);
        expect(event.timestamp, updatedAt);
        expect(event.relatedId, note.id);
        expect(event.status, TimelineEventStatus.info);
      }
      expect(
        NoteTimelineAdapter.eventIdFor(note, NoteTimelineMutation.created),
        'note:note-1:created:${updatedAt.microsecondsSinceEpoch}',
      );
    },
  );
}

final class _TokenWriter implements BinaryWriter {
  final List<Object?> values = <Object?>[];

  @override
  void write<T>(T value, {bool writeTypeId = true}) => values.add(value);

  @override
  void writeInt(int value) => values.add(value);

  @override
  void writeString(
    String value, {
    bool writeByteCount = true,
    dynamic encoder,
  }) => values.add(value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TokenReader implements BinaryReader {
  _TokenReader(List<Object?> values) : _values = List<Object?>.from(values);

  final List<Object?> _values;
  int _index = 0;

  @override
  int get availableBytes => _values.length - _index;

  @override
  dynamic read([int? typeId]) => _values[_index++];

  @override
  int readInt() => _values[_index++]! as int;

  @override
  String readString([int? byteCount, dynamic decoder]) =>
      _values[_index++]! as String;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TimelineRepository implements ITimelineRepository {
  final List<TimelineEventEntity> events = <TimelineEventEntity>[];

  @override
  bool get lastReadCorrupted => false;

  @override
  Future<void> addEvent(TimelineEventEntity event) async => events.add(event);

  @override
  List<TimelineEventEntity> getEvents() =>
      List<TimelineEventEntity>.unmodifiable(events);

  @override
  Future<void> removeEvent(String id) async {
    events.removeWhere((TimelineEventEntity event) => event.id == id);
  }

  @override
  Future<void> saveEvents(List<TimelineEventEntity> events) async {
    this.events
      ..clear()
      ..addAll(events);
  }
}
