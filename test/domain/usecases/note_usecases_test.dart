import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/note_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoteRepository implements INoteRepository {
  final List<NoteEntity> notes = <NoteEntity>[];

  @override
  Future<void> deleteNote(String id) async {
    notes.removeWhere((NoteEntity note) => note.id == id);
  }

  @override
  Future<List<NoteEntity>> getNotes() async => List<NoteEntity>.of(notes);

  @override
  Future<void> saveNote(NoteEntity note) async {
    final int index = notes.indexWhere((NoteEntity item) => item.id == note.id);
    if (index < 0) {
      notes.insert(0, note);
    } else {
      notes[index] = note;
    }
  }
}

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 12);
  late _NoteRepository repository;

  setUp(() => repository = _NoteRepository());

  test('create rejects blank titles and persists a trimmed note', () async {
    expect(await CreateNote(repository)(title: '   ', now: now), isNull);
    expect(repository.notes, isEmpty);

    final NoteEntity? note = await CreateNote(repository)(
      title: '  Decision context  ',
      body: '  Keep this  ',
      id: 'n1',
      now: now,
    );

    expect(note?.title, 'Decision context');
    expect(note?.body, 'Keep this');
    expect(await GetNotes(repository)(), hasLength(1));
  });

  test('update, archive, and delete preserve lifecycle ownership', () async {
    final NoteEntity note = (await CreateNote(repository)(
      title: 'Context',
      id: 'n1',
      now: now,
    ))!;
    final NoteEntity updated = await UpdateNote(repository)(
      note.copyWith(title: 'Updated'),
      now: now.add(const Duration(hours: 1)),
    );
    final NoteEntity? archived = await ArchiveNote(repository)(
      'n1',
      now: now.add(const Duration(hours: 2)),
    );

    expect(updated.title, 'Updated');
    expect(archived?.isArchived, isTrue);

    await DeleteNote(repository)('n1');
    expect(await GetNotes(repository)(), isEmpty);
  });
}
