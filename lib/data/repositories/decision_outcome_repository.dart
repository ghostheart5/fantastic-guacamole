import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';

class DecisionOutcomeRepository implements IDecisionOutcomeRepository {
  DecisionOutcomeRepository(this._store, this._scope, {this.maxRecords = 200});

  final SharedPrefsStore _store;
  final AccountStorageScope _scope;
  final int maxRecords;
  Future<void> _tail = Future<void>.value();

  String get _key {
    final String? namespace = _scope.v2Namespace;
    if (!_scope.isWritable || namespace == null) {
      throw StateError('Decision outcomes require authenticated storage.');
    }
    return 'chronospark.decision_outcomes.v1.$namespace';
  }

  @override
  Future<List<DecisionOutcomeEntity>> load() async {
    await _store.init();
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) return <DecisionOutcomeEntity>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Decision outcome storage is not a list.');
    }
    return decoded
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
  }

  @override
  Future<void> record(DecisionOutcomeEntity outcome) {
    final Future<void> operation = _tail.then((_) async {
      if (outcome.decisionId.trim().isEmpty || outcome.surface.trim().isEmpty) {
        throw ArgumentError('Decision outcome identity must not be empty.');
      }
      final List<DecisionOutcomeEntity> values = await load();
      if (values.any((DecisionOutcomeEntity value) => value.id == outcome.id)) {
        return;
      }
      final List<DecisionOutcomeEntity> next =
          <DecisionOutcomeEntity>[...values, outcome]..sort(
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

  Future<void> drain() => _tail.catchError((Object _) {});
}
