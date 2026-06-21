import '../../entities/archive_record.dart';
import '../../entities/chronolog_record.dart';
import '../../entities/note_record.dart';

class ChronologsBundle {
  final List<ChronologRecord> logs;
  final List<NoteRecord> notes;
  final List<ArchiveRecord> archives;

  const ChronologsBundle({
    required this.logs,
    required this.notes,
    required this.archives,
  });
}

class LoadChronologsUseCase {
  ChronologsBundle call({
    required List<ChronologRecord> logs,
    required List<NoteRecord> notes,
    required List<ArchiveRecord> archives,
  }) {
    return ChronologsBundle(logs: logs, notes: notes, archives: archives);
  }
}
