import 'dart:convert';

import 'package:fantastic_guacamole/data/repositories/intervention_outcome_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/history/history_event.dart';
import 'package:fantastic_guacamole/domain/interventions/intervention.dart';
import 'package:fantastic_guacamole/domain/interventions/intervention_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime occurredAt = DateTime.utc(2026, 8, 12, 18);

  group('Intervention and outcome', () {
    test('keeps proposed intervention distinct from accepted outcome', () {
      final Intervention intervention = Intervention(
        id: 'intervention-1',
        trigger: 'overload',
        reason: 'Several tasks are due soon.',
        evidence: const <String>['three due tasks'],
        severity: InterventionSeverity.medium,
        confidence: .7,
        suggestedAction: 'Move one task to tomorrow.',
        createdAt: occurredAt,
        entityId: 'task-1',
        entityType: 'task',
      );
      final InterventionOutcome outcome = InterventionOutcome(
        id: 'outcome-1',
        interventionId: 'intervention-1',
        status: InterventionOutcomeStatus.accepted,
        occurredAt: DateTime.utc(2026, 8, 12, 19),
      );

      intervention.validate();
      outcome.validate();
      expect(outcome.interventionId, intervention.id);
      expect(outcome.status, isNot(InterventionOutcomeStatus.legacy));
    });

    test('preserves each user-controlled outcome semantic', () {
      final List<InterventionOutcome> outcomes = <InterventionOutcome>[
        _outcome(InterventionOutcomeStatus.accepted),
        _outcome(InterventionOutcomeStatus.modified, modifiedAction: 'Split it into two tasks.'),
        _outcome(InterventionOutcomeStatus.dismissed),
        _outcome(InterventionOutcomeStatus.snoozed, snoozedUntil: occurredAt.add(const Duration(hours: 2))),
        _outcome(InterventionOutcomeStatus.disabled, disabledScope: 'overload_prompt'),
      ];

      for (final InterventionOutcome outcome in outcomes) {
        outcome.validate();
      }
      expect(outcomes.map((InterventionOutcome value) => value.status), containsAll(InterventionOutcomeStatus.values.take(5)));
    });

    test('explanation request is interaction metadata, not an outcome state', () {
      final InterventionOutcome outcome = _outcome(
        InterventionOutcomeStatus.snoozed,
        snoozedUntil: occurredAt.add(const Duration(hours: 1)),
        explanationRequestedAt: occurredAt,
      );

      expect(outcome.requestedExplanation, isTrue);
      expect(outcome.status, InterventionOutcomeStatus.snoozed);
    });

    test('round-trips UTC metadata and preserves unknown legacy status', () {
      final InterventionOutcome original = _outcome(
        InterventionOutcomeStatus.modified,
        modifiedAction: 'Do it after lunch.',
        explanationRequestedAt: occurredAt,
      );
      final InterventionOutcome decoded = InterventionOutcome.fromJson(original.toJson());
      final InterventionOutcome legacy = InterventionOutcome.fromJson(<String, dynamic>{
        'id': 'legacy',
        'interventionId': 'old',
        'status': 'declined_for_now',
        'occurredAt': '2026-08-12T18:00:00.000Z',
      });

      expect(decoded.occurredAt, occurredAt);
      expect(decoded.modifiedAction, 'Do it after lunch.');
      expect(decoded.requestedExplanation, isTrue);
      expect(legacy.status, InterventionOutcomeStatus.legacy);
      expect(legacy.legacyStatus, 'declined_for_now');
    });

    test('maps meaningful user outcomes to typed HistoryEvent facts', () {
      final HistoryEvent event = _outcome(
        InterventionOutcomeStatus.disabled,
        disabledScope: 'overload_prompt',
      ).toHistoryEvent();

      expect(event.kind, HistoryEventKind.interventionDisabled);
      expect(event.entityType, HistoryEntityType.intervention);
      expect(event.entityId, 'intervention-1');
      expect(event.source, HistoryEventSource.user);
      expect(event.occurredAt, occurredAt);
    });
  });

  group('InterventionOutcomeRepository', () {
    test('persists canonical outcomes and reads them in chronological order', () async {
      final _MemoryStore store = _MemoryStore();
      final InterventionOutcomeRepository repository = InterventionOutcomeRepository(store);
      await repository.addOutcome(_outcome(InterventionOutcomeStatus.accepted));
      await repository.addOutcome(
        InterventionOutcome(
          id: 'later',
          interventionId: 'intervention-2',
          status: InterventionOutcomeStatus.dismissed,
          occurredAt: occurredAt.add(const Duration(minutes: 1)),
        ),
      );

      final List<dynamic> values = jsonDecode(store.values[InterventionOutcomeRepository.storageKey]!) as List<dynamic>;
      expect((values.first as Map<String, dynamic>)['schemaVersion'], 1);
      expect(repository.getOutcomes().first.id, 'later');
    });
  });
}

InterventionOutcome _outcome(
  InterventionOutcomeStatus status, {
  String? modifiedAction,
  DateTime? snoozedUntil,
  String? disabledScope,
  DateTime? explanationRequestedAt,
}) => InterventionOutcome(
  id: 'outcome-${status.name}',
  interventionId: 'intervention-1',
  status: status,
  occurredAt: DateTime.utc(2026, 8, 12, 18),
  modifiedAction: modifiedAction,
  snoozedUntil: snoozedUntil,
  disabledScope: disabledScope,
  explanationRequestedAt: explanationRequestedAt,
);

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<void> clear() async => values.clear();
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => values[key];
  @override
  Future<void> save(String key, String value) async => values[key] = value;
}
