part of 'backup_service.dart';

extension PlanningCloudBackup on BackupService {
  /// Called only after the owner confirms the expanded upload and replacement
  /// scope. Legacy automatic sync continues to use its narrower v4 envelope.
  Future<VersionedBackupSnapshot> createPlanningCloudBackup() async {
    late Map<String, dynamic> payload;
    await runAccountStorageMutation(() async {
      final canonical = await _createFullBackup();
      final events = _readTimelineForBackup();
      payload = <String, dynamic>{
        ...canonical,
        'version': BackupService._planningCloudVersion,
        'manifest': planningCloudBackupManifest(),
        'timelineEvents': events.map((event) => event.toJson()).toList(),
        'recordCounts': <String, dynamic>{
          ...canonical['recordCounts'] as Map<String, dynamic>,
          'timeline': events.length,
        },
      };
      validateFullBackup(payload);
    }, coordinator: _mutationCoordinator);
    return VersionedBackupSnapshot(payload, localGeneration);
  }

  List<TimelineEventEntity> _readTimelineForBackup() {
    final repository = timelineRepository;
    if (repository == null) {
      throw StateError('Timeline backup is unavailable in this build.');
    }
    final events = repository.getEvents();
    if (repository.lastReadCorrupted) {
      throw const FormatException(
        'Stored Timeline history needs recovery before backup.',
      );
    }
    return _timelineEntitiesFromRaw(
      events.map((event) => event.toJson()).toList(),
    );
  }

  List<TimelineEventEntity> _timelineEntitiesFromRaw(Object? raw) {
    final values = _strictRecordList(raw, field: 'timelineEvents');
    final ids = <String>{};
    return values
        .map((value) {
          _requireNonEmptyString(value, 'id', field: 'timeline event');
          _requireNonEmptyString(value, 'title', field: 'timeline event');
          _requireNonEmptyString(value, 'detail', field: 'timeline event');
          _requireValidDate(
            value,
            'timestamp',
            required: true,
            field: 'timeline event',
          );
          _requireValidDate(
            value,
            'dueAt',
            required: false,
            field: 'timeline event',
          );
          if (!TimelineEventType.values.any(
                (type) => type.name == value['type'],
              ) ||
              !TimelineEventStatus.values.any(
                (status) => status.name == value['status'],
              ) ||
              value['userOverride'] is! bool ||
              (value['dateOnly'] != null && value['dateOnly'] is! bool)) {
            throw const FormatException(
              'Backup Timeline event fields are invalid.',
            );
          }
          for (final field in [
            'phase',
            'relatedId',
            'sourceFeature',
            'decisionId',
          ]) {
            if (value[field] != null && value[field] is! String) {
              throw const FormatException(
                'Backup Timeline event metadata is invalid.',
              );
            }
          }
          final event = TimelineEventEntity.fromJson(value);
          event.validate();
          if (!ids.add(event.id)) {
            throw const FormatException(
              'Backup contains duplicate Timeline event IDs.',
            );
          }
          return event;
        })
        .toList(growable: false);
  }
}
