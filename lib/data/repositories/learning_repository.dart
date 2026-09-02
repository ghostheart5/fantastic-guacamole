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
/// SHIPPING SURFACE: task completion, task skip, and recorded decision
/// outcomes invoke the bound learning use cases. Failures are isolated from
/// the primary task mutation, while successfully persisted weights feed the
/// decision engine on later reads.
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

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // Preserve the invalid payload for support/recovery and return a safe
      // empty state instead of disabling planning and prediction.
      return null;
    }
    if (decoded is! Map) {
      // Corrupted payload: surface as "no state" rather than a wrong state, and
      // do not overwrite storage so the raw value stays recoverable.
      return null;
    }

    final Map<String, dynamic> json = decoded.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
    return LearningEntity.fromJson(json);
  }

  @override
  Future<void> saveState(LearningEntity state) {
    state.validate();
    return _store.writeString(_stateKey, jsonEncode(state.toJson()));
  }
}
