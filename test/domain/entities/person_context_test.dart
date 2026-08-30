import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 30, 12);

  PersonContextSignal signal({
    String id = 'signal-1',
    PersonContextKind kind = PersonContextKind.value,
    PersonContextSource source = PersonContextSource.userAuthored,
    PersonContextConsent consent = PersonContextConsent.granted,
    DateTime? consentedAt,
    DateTime? freshUntil,
    DateTime? expiresAt,
    Set<PersonContextSurface> surfaces = const <PersonContextSurface>{
      PersonContextSurface.smartPlanner,
    },
  }) => PersonContextSignal(
    id: id,
    kind: kind,
    value: 'Family time matters',
    source: source,
    consent: consent,
    consentedAt: consentedAt ?? now,
    purpose: PersonContextPurpose.decisionSupport,
    surfaceScopes: surfaces,
    recordedAt: now,
    freshUntil: freshUntil ?? now.add(const Duration(days: 30)),
    expiresAt: expiresAt ?? now.add(const Duration(days: 60)),
    exportBehavior: PersonContextExportBehavior.include,
    deletionBehavior: PersonContextDeletionBehavior.userRemovable,
  );

  test('surface view includes only consented fresh scoped signals', () {
    final PersonContextSpine spine = PersonContextSpine(
      accountScopeId: 'v2.account',
      updatedAt: now,
      signals: <PersonContextSignal>[
        signal(),
        signal(
          id: 'signal-2',
          consent: PersonContextConsent.withdrawn,
          consentedAt: null,
        ).corrected(
          value: 'Still hidden',
          correctedAt: now,
          reason: 'Correction',
          freshUntil: now.add(const Duration(days: 1)),
          expiresAt: now.add(const Duration(days: 2)),
        ),
      ],
    );

    final PersonContextView planner = spine.forSurface(
      PersonContextSurface.smartPlanner,
      now,
    );
    final PersonContextView nexus = spine.forSurface(
      PersonContextSurface.nexus,
      now,
    );

    expect(planner.signals, hasLength(1));
    expect(planner.unknownKinds, isNot(contains(PersonContextKind.value)));
    expect(nexus.signals, isEmpty);
    expect(nexus.unknownKinds, contains(PersonContextKind.value));
  });

  test('lasting identity cannot be inferred from an outcome', () {
    expect(
      () => signal(
        kind: PersonContextKind.role,
        source: PersonContextSource.confirmedOutcome,
      ),
      throwsStateError,
    );
  });

  test('present capacity expires from freshness within 24 hours', () {
    expect(
      () => signal(
        kind: PersonContextKind.presentCapacity,
        freshUntil: now.add(const Duration(hours: 25)),
      ),
      throwsStateError,
    );
  });

  test('future consent remains unavailable until it takes effect', () {
    final PersonContextSignal futureConsent = signal(
      consentedAt: now.add(const Duration(minutes: 1)),
    );

    expect(
      futureConsent.isAvailableTo(PersonContextSurface.smartPlanner, now),
      isFalse,
    );
  });

  test('correction history is reviewable and bounded', () {
    PersonContextSignal current = signal();
    for (int index = 0; index < 25; index += 1) {
      final DateTime correctedAt = now.add(Duration(minutes: index + 1));
      current = current.corrected(
        value: 'Value $index',
        correctedAt: correctedAt,
        reason: 'User correction $index',
        freshUntil: correctedAt.add(const Duration(days: 1)),
        expiresAt: correctedAt.add(const Duration(days: 2)),
      );
    }
    expect(
      current.corrections,
      hasLength(PersonContextSignal.maxCorrectionHistory),
    );
    expect(current.corrections.first.previousValue, 'Value 4');
    expect(current.source, PersonContextSource.userAuthored);
  });

  test('strict schema round-trips governance metadata', () {
    final PersonContextSpine original = PersonContextSpine(
      accountScopeId: 'v2.account',
      updatedAt: now,
      signals: <PersonContextSignal>[signal()],
    );
    final PersonContextSpine restored = PersonContextSpine.fromJson(
      original.toJson(),
    );
    expect(restored.accountScopeId, original.accountScopeId);
    expect(restored.signals.single.toJson(), original.signals.single.toJson());
  });

  test('signal text and collection size are bounded', () {
    expect(
      () => PersonContextSignal(
        id: 'oversized',
        kind: PersonContextKind.value,
        value: 'x' * (PersonContextSignal.maxValueLength + 1),
        source: PersonContextSource.userAuthored,
        consent: PersonContextConsent.granted,
        consentedAt: now,
        purpose: PersonContextPurpose.decisionSupport,
        surfaceScopes: const <PersonContextSurface>{PersonContextSurface.nexus},
        recordedAt: now,
        freshUntil: now.add(const Duration(days: 1)),
        expiresAt: now.add(const Duration(days: 2)),
        exportBehavior: PersonContextExportBehavior.include,
        deletionBehavior: PersonContextDeletionBehavior.userRemovable,
      ),
      throwsStateError,
    );

    expect(
      () => PersonContextSpine(
        accountScopeId: 'v2.account',
        updatedAt: now,
        signals: List<PersonContextSignal>.generate(
          PersonContextSpine.maxSignals + 1,
          (int index) => signal(id: 'signal-$index'),
        ),
      ),
      throwsStateError,
    );
  });
}
