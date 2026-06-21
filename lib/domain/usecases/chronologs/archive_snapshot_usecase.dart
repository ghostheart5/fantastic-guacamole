import '../../entities/archive_record.dart';

class ArchiveSnapshotUseCase {
  List<ArchiveRecord> call(List<ArchiveRecord> current, String label) {
    final DateTime now = DateTime.now();
    final ArchiveRecord next = ArchiveRecord(
      id: now.microsecondsSinceEpoch.toString(),
      label: label,
      createdAt: now,
    );
    return <ArchiveRecord>[next, ...current];
  }
}
