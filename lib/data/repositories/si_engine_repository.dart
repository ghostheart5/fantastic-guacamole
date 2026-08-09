import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';

class SiEngineRepository implements ISiRepository {
  SiEngineRepository(this._store);

  static const String _stateKey = 'si_state_entity_v1';

  final SecureStore _store;

  @override
  Future<SiStateEntity?> getCurrentState() async {
    final String? raw = await _store.readString(_stateKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Stored SI state is not a JSON object.');
      }
      return _fromJson(
        decoded.map<String, dynamic>(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ),
      );
    } on Object catch (error) {
      Logger.error('Stored SI engine state is corrupt.', error);
      throw StateError('Stored SI state is corrupt.');
    }
  }

  @override
  Future<void> saveState(SiStateEntity state) {
    state.validate();
    return _store.writeString(_stateKey, jsonEncode(_toJson(state)));
  }

  static Map<String, dynamic> _toJson(SiStateEntity state) {
    return <String, dynamic>{
      'energy': state.energy,
      'focus': state.focus,
      'fatigue': state.fatigue,
      'mood': state.mood,
      'confidence': state.confidence,
      'anticipatesConfusion': state.anticipatesConfusion,
      'primaryInstinct': state.primaryInstinct,
      'avoidOverwhelm': state.avoidOverwhelm,
      'frictionScore': state.frictionScore,
      'highFriction': state.highFriction,
      'lastUpdated': state.lastUpdated.toIso8601String(),
    };
  }

  static SiStateEntity _fromJson(Map<String, dynamic> json) {
    final double? energy = (json['energy'] as num?)?.toDouble();
    final double? focus = (json['focus'] as num?)?.toDouble();
    final double? fatigue = (json['fatigue'] as num?)?.toDouble();
    final DateTime? lastUpdated = DateTime.tryParse(
      json['lastUpdated']?.toString() ?? '',
    );
    if (energy == null ||
        focus == null ||
        fatigue == null ||
        lastUpdated == null) {
      throw const FormatException(
        'Stored SI state has missing required fields.',
      );
    }
    return SiStateEntity(
      energy: energy,
      focus: focus,
      fatigue: fatigue,
      mood: json['mood']?.toString() ?? 'neutral',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      anticipatesConfusion: json['anticipatesConfusion'] as bool? ?? false,
      primaryInstinct: json['primaryInstinct']?.toString() ?? 'progress_first',
      avoidOverwhelm: json['avoidOverwhelm'] as bool? ?? false,
      frictionScore: (json['frictionScore'] as num?)?.toDouble() ?? 0.0,
      highFriction: json['highFriction'] as bool? ?? false,
      lastUpdated: lastUpdated,
    );
  }
}
