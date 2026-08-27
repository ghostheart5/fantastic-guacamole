import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_milestone_repository.dart';

class MilestoneRepository implements IMilestoneRepository {
  const MilestoneRepository(this._store);

  static const String storageKey = 'milestones_v1';

  final SecureStore _store;

  @override
  Future<List<MilestoneEntity>> getMilestones() async {
    final String? raw = await _store.readString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <MilestoneEntity>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const <MilestoneEntity>[];
      final List<MilestoneEntity> milestones = decoded
          .whereType<Map<String, dynamic>>()
          .map(MilestoneEntity.fromJson)
          .toList(growable: false);
      milestones.sort(
        (MilestoneEntity first, MilestoneEntity second) =>
            second.updatedAt.compareTo(first.updatedAt),
      );
      return milestones;
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode milestones; returning an empty result.',
        error,
        stackTrace,
      );
      return const <MilestoneEntity>[];
    }
  }

  @override
  Future<void> saveMilestones(List<MilestoneEntity> milestones) {
    return _store.writeString(
      storageKey,
      jsonEncode(
        milestones
            .map((MilestoneEntity milestone) => milestone.toJson())
            .toList(growable: false),
      ),
    );
  }
}
