// Dart SDK imports.
import 'dart:convert';

// Package imports.
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/learning_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_learning_repository.dart';

/// Persists the adaptive learning weights used by `LearningPolicy`.
///
/// Uses the shared SecureStore + JSON repository pattern.
///
/// PLANNED SURFACE: this repository is bound in DI and fully functional, but
/// `ApplyLearningFeedback` is not yet invoked automatically from the task
/// completion/skip flows — wiring that in changes planner behaviour and is a
/// separate, deliberate decision. Until then the weights only change when a
/// caller runs the learning use cases explicitly.
class LearningRepository implements ILearningRepository {
  LearningRepository(this._store);

  static const String _stateKey = 'learning_state_v1';
  final SecureStore _store;

  @override
  Future<LearningEntity?> getState() async {
    final String? raw = await _store.readString(_stateKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      // Corrupted payload: surface as "no state" rather than a wrong state, and
      // do not overwrite storage so the raw value stays recoverable.
      return null;
    }

    final Map<String, dynamic> json = decoded.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
    return LearningEntity(
      effortWeight: (json['effortWeight'] as num?)?.toDouble() ?? 1.0,
      priorityWeight: (json['priorityWeight'] as num?)?.toDouble() ?? 1.0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> saveState(LearningEntity state) {
    return _store.writeString(
      _stateKey,
      jsonEncode(<String, dynamic>{
        'effortWeight': state.effortWeight,
        'priorityWeight': state.priorityWeight,
        'completed': state.completed,
        'skipped': state.skipped,
      }),
    );
  }
}
