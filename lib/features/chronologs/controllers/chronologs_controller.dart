import '../../../data/repositories/chronologs_repository.dart';
import '../../../data/repositories/chronologs_repository_impl.dart';
import '../../../data/services/chronologs_service.dart';
import '../../../domain/entities/archive_record.dart';
import '../../../domain/entities/chronolog_record.dart';
import '../../../domain/entities/note_record.dart';
import '../../../domain/usecases/chronologs/add_chronolog_note_usecase.dart';
import '../../../domain/usecases/chronologs/archive_snapshot_usecase.dart';
import '../../../domain/usecases/chronologs/load_chronologs_usecase.dart';

class ChronoLogsState {
  final List<String> completedTasks;
  final List<String> pastMissions;
  final List<String> pastSchedules;
  final List<String> notes;
  final List<String> dailyLogs;
  final List<String> archivedEvents;
  final List<String> oldRoutines;
  final List<String> archives;

  const ChronoLogsState({
    required this.completedTasks,
    required this.pastMissions,
    required this.pastSchedules,
    required this.notes,
    required this.dailyLogs,
    required this.archivedEvents,
    required this.oldRoutines,
    required this.archives,
  });
}

class ChronoLogsController {
  ChronoLogsController({ChronologsRepository? repository})
    : _repository = repository ?? ChronologsRepositoryImpl(),
      _loadChronologsUseCase = LoadChronologsUseCase(),
      _addChronologNoteUseCase = AddChronologNoteUseCase(),
      _archiveSnapshotUseCase = ArchiveSnapshotUseCase();

  final ChronologsRepository _repository;
  final LoadChronologsUseCase _loadChronologsUseCase;
  final AddChronologNoteUseCase _addChronologNoteUseCase;
  final ArchiveSnapshotUseCase _archiveSnapshotUseCase;

  Future<ChronoLogsState> load() async {
    final ChronoLogsPayload payload = await _repository.load();
    final List<ChronologRecord> logs = payload.completedTasks
        .map(
          (String value) => ChronologRecord(
            timestamp: DateTime.now(),
            category: 'completed',
            value: value,
          ),
        )
        .toList();
    final List<NoteRecord> notes = payload.notes
        .map((String n) => NoteRecord(timestamp: DateTime.now(), note: n))
        .toList();
    final List<ArchiveRecord> archives = payload.archives
        .map(
          (String a) =>
              ArchiveRecord(id: a, label: a, createdAt: DateTime.now()),
        )
        .toList();

    final ChronologsBundle bundle = _loadChronologsUseCase(
      logs: logs,
      notes: notes,
      archives: archives,
    );

    return ChronoLogsState(
      completedTasks: bundle.logs.map((ChronologRecord r) => r.value).toList(),
      pastMissions: payload.pastMissions,
      pastSchedules: payload.pastSchedules,
      notes: bundle.notes.map((NoteRecord n) => n.note).toList(),
      dailyLogs: payload.dailyLogs,
      archivedEvents: payload.archivedEvents,
      oldRoutines: payload.oldRoutines,
      archives: bundle.archives.map((ArchiveRecord a) => a.label).toList(),
    );
  }

  Future<ChronoLogsState> addNote(ChronoLogsState state, String value) async {
    final List<NoteRecord> current = state.notes
        .map((String n) => NoteRecord(timestamp: DateTime.now(), note: n))
        .toList();
    final List<NoteRecord> updated = _addChronologNoteUseCase(current, value);
    if (updated.length == current.length) {
      return state;
    }

    final ChronoLogsState next = ChronoLogsState(
      completedTasks: state.completedTasks,
      pastMissions: state.pastMissions,
      pastSchedules: state.pastSchedules,
      notes: updated.map((NoteRecord n) => n.note).toList(),
      dailyLogs: <String>[
        '${DateTime.now().toIso8601String()} :: NOTE ${value.trim()}',
        ...state.dailyLogs,
      ],
      archivedEvents: state.archivedEvents,
      oldRoutines: state.oldRoutines,
      archives: state.archives,
    );
    await _save(next);
    return next;
  }

  Future<ChronoLogsState> archiveCompleted(ChronoLogsState state) async {
    final List<ArchiveRecord> current = state.archives
        .map(
          (String a) =>
              ArchiveRecord(id: a, label: a, createdAt: DateTime.now()),
        )
        .toList();

    final DateTime now = DateTime.now();
    final String label =
        'Archive ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final List<ArchiveRecord> updated = _archiveSnapshotUseCase(current, label);

    final ChronoLogsState next = ChronoLogsState(
      completedTasks: state.completedTasks,
      pastMissions: state.pastMissions,
      pastSchedules: state.pastSchedules,
      notes: state.notes,
      dailyLogs: <String>[
        '${DateTime.now().toIso8601String()} :: Snapshot archived',
        ...state.dailyLogs,
      ],
      archivedEvents: <String>[
        'Event archive generated: $label',
        ...state.archivedEvents,
      ],
      oldRoutines: state.oldRoutines,
      archives: updated.map((ArchiveRecord a) => a.label).toList(),
    );
    await _save(next);
    return next;
  }

  Future<void> _save(ChronoLogsState state) async {
    await _repository.save(
      ChronoLogsPayload(
        completedTasks: state.completedTasks,
        pastMissions: state.pastMissions,
        pastSchedules: state.pastSchedules,
        notes: state.notes,
        dailyLogs: state.dailyLogs,
        archivedEvents: state.archivedEvents,
        oldRoutines: state.oldRoutines,
        archives: state.archives,
      ),
    );
  }
}
