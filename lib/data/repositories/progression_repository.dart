import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/progression_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_progression_repository.dart';

class ProgressionRepository implements IProgressionRepository {
  ProgressionRepository(this._store);

  static const String _key = 'progression_entity_v1';

  final HiveStorage<String> _store;

  @override
  Future<ProgressionEntity?> getProgression() async {
    await _store.open();
    final String? raw = _store.get(_key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Progression storage is not an object.');
      }
      final int? xp = (decoded['xp'] as num?)?.toInt();
      final int? level = (decoded['level'] as num?)?.toInt();
      final int? streak = (decoded['streak'] as num?)?.toInt();
      if (xp == null || level == null || streak == null) {
        throw const FormatException('Progression storage has missing required fields.');
      }
      return ProgressionEntity(
        xp: xp,
        level: level,
        streak: streak,
      );
    } on Object catch (error) {
      throw StorageException('Progression storage is corrupted: $error');
    }
  }

  @override
  Future<void> saveProgression(ProgressionEntity progression) {
    return _store.put(
      _key,
      jsonEncode(<String, dynamic>{
        'xp': progression.xp,
        'level': progression.level,
        'streak': progression.streak,
      }),
    );
  }
}
