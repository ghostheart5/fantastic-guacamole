import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';

abstract interface class IExactDecisionOutcomeSnapshotRepository {
  Future<void> replaceSnapshot(List<DecisionOutcomeEntity> outcomes);
}

class DecisionOutcomeRepository
    implements
        IDecisionOutcomeRepository,
        IExactDecisionOutcomeSnapshotRepository {
  DecisionOutcomeRepository(this._store, this._scope, {this.maxRecords = 256});

  final SharedPrefsStore _store;
  final AccountStorageScope _scope;

  /// Explicit local retention bound. Oldest observations are removed first.
  final int maxRecords;
  Future<void> _tail = Future<void>.value();

  String get _key {
    final String? namespace = _scope.v2Namespace;
    if (!_scope.isWritable || namespace == null) {
      throw StateError('Decision outcomes require authenticated storage.');
    }
    return 'chronospark.decision_outcomes.v1.$namespace';
  }

  String get _pausedKey => '$_key.paused';

  @override
  Future<List<DecisionOutcomeEntity>> load() async {
    await _store.init();
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) return <DecisionOutcomeEntity>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Decision outcome storage is not a list.');
    }
    final List<DecisionOutcomeEntity> values = decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> value) => DecisionOutcomeEntity.fromJson(
            value.map<String, dynamic>(
              (dynamic key, dynamic item) => MapEntry(key.toString(), item),
            ),
          ),
        )
        .where((DecisionOutcomeEntity value) => value.decisionId.isNotEmpty)
        .toList(growable: false);
    if (values.length <= maxRecords) return values;
    final List<DecisionOutcomeEntity> bounded = values.sublist(
      values.length - maxRecords,
    );
    await _store.save(
      _key,
      jsonEncode(
        bounded
            .map((DecisionOutcomeEntity value) => value.toJson())
            .toList(growable: false),
      ),
    );
    return bounded;
  }

  @override
  Future<void> record(DecisionOutcomeEntity outcome) {
    final Future<void> operation = _tail.then((_) async {
      if (outcome.decisionId.trim().isEmpty || outcome.surface.trim().isEmpty) {
        throw ArgumentError('Decision outcome identity must not be empty.');
      }
      final List<DecisionOutcomeEntity> values = await load();
      final int existingIndex = values.indexWhere(
        (DecisionOutcomeEntity value) => value.id == outcome.id,
      );
      if (existingIndex >= 0) {
        if (outcome.kind != DecisionOutcomeKind.corrected) return;
        values[existingIndex] = outcome;
      }
      final List<DecisionOutcomeEntity> next =
          <DecisionOutcomeEntity>[...values, if (existingIndex < 0) outcome]
            ..sort(
              (DecisionOutcomeEntity first, DecisionOutcomeEntity second) =>
                  first.recordedAt.compareTo(second.recordedAt),
            );
      final int trim = next.length - maxRecords;
      final List<DecisionOutcomeEntity> bounded = trim > 0
          ? next.sublist(trim)
          : next;
      await _store.save(
        _key,
        jsonEncode(
          bounded
              .map((DecisionOutcomeEntity value) => value.toJson())
              .toList(growable: false),
        ),
      );
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> replaceSnapshot(List<DecisionOutcomeEntity> outcomes) {
    final Future<void> operation = _tail.then((_) async {
      await _store.init();
      final List<DecisionOutcomeEntity> sorted = outcomes.toList()
        ..sort(
          (DecisionOutcomeEntity first, DecisionOutcomeEntity second) =>
              first.recordedAt.compareTo(second.recordedAt),
        );
      final int trim = sorted.length - maxRecords;
      final List<DecisionOutcomeEntity> bounded = trim > 0
          ? sorted.sublist(trim)
          : sorted;
      await _store.save(
        _key,
        jsonEncode(
          bounded
              .map((DecisionOutcomeEntity value) => value.toJson())
              .toList(growable: false),
        ),
      );
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<bool> isLearningPaused() async {
    await _store.init();
    return _store.load(_pausedKey) == 'true';
  }

  Future<void> setLearningPaused(bool paused) async {
    await _store.init();
    if (paused) {
      await _store.save(_pausedKey, 'true');
    } else {
      await _store.delete(_pausedKey);
    }
  }

  Future<void> remove(String outcomeId) async {
    final List<DecisionOutcomeEntity> current = await load();
    await replaceSnapshot(
      current
          .where((DecisionOutcomeEntity value) => value.id != outcomeId)
          .toList(growable: false),
    );
  }

  Future<void> clear() => replaceSnapshot(const <DecisionOutcomeEntity>[]);

  Future<void> drain() => _tail.catchError((Object _) {});
}
