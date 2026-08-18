import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_timeline_repository.dart';

enum NoteTimelineMutation { created, updated, archived, deleted }

/// Projects canonical Note mutations into Timeline history without owning notes.
class NoteTimelineAdapter {
  const NoteTimelineAdapter(this._timeline);

  final ITimelineRepository _timeline;

  Future<void> record(NoteEntity note, NoteTimelineMutation mutation) async {
    final String id = eventIdFor(note, mutation);
    if (_timeline.getEvents().any((TimelineEventEntity event) => event.id == id)) {
      return;
    }
    final TimelineEventType type = switch (mutation) {
      NoteTimelineMutation.created => TimelineEventType.noteCreated,
      NoteTimelineMutation.updated => TimelineEventType.noteUpdated,
      NoteTimelineMutation.archived => TimelineEventType.noteArchived,
      NoteTimelineMutation.deleted => TimelineEventType.noteDeleted,
    };
    final String label = switch (mutation) {
      NoteTimelineMutation.created => 'Note Created',
      NoteTimelineMutation.updated => 'Note Updated',
      NoteTimelineMutation.archived => 'Note Archived',
      NoteTimelineMutation.deleted => 'Note Deleted',
    };
    await _timeline.addEvent(TimelineEventEntity(
      id: id,
      type: type,
      title: label,
      detail: note.title,
      timestamp: note.updatedAt,
      status: TimelineEventStatus.info,
      relatedId: note.id,
    ));
  }

  static String eventIdFor(NoteEntity note, NoteTimelineMutation mutation) =>
      'note:${note.id}:${mutation.name}:${note.updatedAt.toUtc().microsecondsSinceEpoch}';
}
