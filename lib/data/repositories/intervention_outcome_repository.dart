import 'dart:convert';

import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_intervention_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interventions/intervention_outcome.dart';

/// Durable authority for user decisions about interventions.
class InterventionOutcomeRepository implements IInterventionOutcomeRepository {
  InterventionOutcomeRepository(this._store);

  static const String storageKey = 'intervention_outcomes_v1';
  final SharedPrefsStore _store;

  @override
  List<InterventionOutcome> getOutcomes() {
    final String? raw = _store.load(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <InterventionOutcome>[];
    try {
      final List<dynamic> values = jsonDecode(raw) as List<dynamic>;
      final List<InterventionOutcome> outcomes = values
          .whereType<Map<String, dynamic>>()
          .map(InterventionOutcome.fromJson)
          .toList(growable: false);
      return <InterventionOutcome>[...outcomes]
        ..sort((InterventionOutcome a, InterventionOutcome b) =>
            b.occurredAt.compareTo(a.occurredAt));
    } on Object catch (error) {
      throw StorageException('Intervention outcome storage is corrupted: $error');
    }
  }

  @override
  Future<void> addOutcome(InterventionOutcome outcome) {
    outcome.validate();
    return saveOutcomes(<InterventionOutcome>[outcome, ...getOutcomes()]);
  }

  @override
  Future<void> saveOutcomes(List<InterventionOutcome> outcomes) {
    for (final InterventionOutcome outcome in outcomes) {
      outcome.validate();
    }
    return _store.save(
      storageKey,
      jsonEncode(outcomes.map((InterventionOutcome value) => value.toJson()).toList()),
    );
  }

  @override
  Future<void> removeOutcome(String id) {
    return saveOutcomes(
      getOutcomes()
          .where((InterventionOutcome outcome) => outcome.id != id)
          .toList(growable: false),
    );
  }
}
