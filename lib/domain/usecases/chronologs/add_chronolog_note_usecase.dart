import '../../entities/note_record.dart';

class AddChronologNoteUseCase {
  List<NoteRecord> call(List<NoteRecord> current, String note) {
    final String trimmed = note.trim();
    if (trimmed.isEmpty) {
      return current;
    }

    return <NoteRecord>[
      NoteRecord(timestamp: DateTime.now(), note: trimmed),
      ...current,
    ];
  }
}
