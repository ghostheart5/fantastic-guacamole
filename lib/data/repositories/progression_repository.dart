import 'dart:convert';

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
        return null;
      }
      return ProgressionEntity(
        xp: (decoded['xp'] as num?)?.toInt() ?? 0,
        level: (decoded['level'] as num?)?.toInt() ?? 1,
        streak: (decoded['streak'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
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
