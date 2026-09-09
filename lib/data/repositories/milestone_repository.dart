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
      if (decoded is! List<dynamic>) {
        throw const FormatException('Stored milestones must be a list.');
      }
      final List<MilestoneEntity> milestones = decoded
          .map((dynamic item) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException(
                'Stored milestone must be an object.',
              );
            }
            for (final String field in <String>['id', 'title']) {
              final dynamic value = item[field];
              if (value is! String || value.trim().isEmpty) {
                throw FormatException(
                  'Stored milestone has an invalid $field.',
                );
              }
            }
            for (final String field in <String>['createdAt', 'updatedAt']) {
              final dynamic value = item[field];
              if (value is! String || DateTime.tryParse(value) == null) {
                throw FormatException(
                  'Stored milestone has an invalid $field.',
                );
              }
            }
            return MilestoneEntity.fromJson(item);
          })
          .toList(growable: false);
      milestones.sort(
        (MilestoneEntity first, MilestoneEntity second) =>
            second.updatedAt.compareTo(first.updatedAt),
      );
      return milestones;
    } on Object catch (_, stackTrace) {
      Logger.recordDiagnosticCode(
        code: 'storage.milestones_decode_failed',
        stackTrace: stackTrace,
      );
      // Do not present incomplete data as a healthy empty collection. The
      // original bytes remain untouched, and read-before-write use cases stop.
      throw const FormatException(
        'Stored milestones are unavailable; original data was preserved.',
      );
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
