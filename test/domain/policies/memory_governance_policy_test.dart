import 'dart:math';

import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/policies/memory_governance_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('governance exceptions retain their user-safe diagnostic message', () {
    expect(
      const MemoryGovernanceException(
        'invalid_memory',
        'Memory could not be saved.',
      ).toString(),
      'Memory could not be saved.',
    );
  });

  test('accepts a bounded planning preference', () {
    expect(
      MemoryGovernancePolicy.validatePreferenceText(
        'Prefer one small next step before optional stretch ideas.',
      ),
      'Prefer one small next step before optional stretch ideas.',
    );
  });

  test('keeps crisis and raw emotional disclosure ephemeral', () {
    expect(
      () => MemoryGovernancePolicy.validatePreferenceText(
        'I want to kill myself tonight',
      ),
      throwsA(
        isA<MemoryGovernanceException>().having(
          (MemoryGovernanceException error) => error.code,
          'code',
          'crisis_memory_blocked',
        ),
      ),
    );
    expect(
      () => MemoryGovernancePolicy.validatePreferenceText(
        'I feel overwhelmed and ashamed',
      ),
      throwsA(
        isA<MemoryGovernanceException>().having(
          (MemoryGovernanceException error) => error.code,
          'code',
          'emotional_memory_blocked',
        ),
      ),
    );
  });

  test('expiry must be after creation and no more than one year away', () {
    final DateTime createdAt = DateTime(2026, 8, 20, 12);
    final DateTime validExpiry = DateTime(2026, 11, 18, 12);

    expect(
      MemoryGovernancePolicy.validateExpiry(
        createdAt: createdAt,
        expiresAt: validExpiry,
      ),
      validExpiry.toUtc(),
    );
    expect(
      () => MemoryGovernancePolicy.validateExpiry(
        createdAt: createdAt,
        expiresAt: createdAt,
      ),
      throwsA(
        isA<MemoryGovernanceException>().having(
          (MemoryGovernanceException error) => error.code,
          'code',
          'invalid_expiry',
        ),
      ),
    );
    expect(
      () => MemoryGovernancePolicy.validateExpiry(
        createdAt: createdAt,
        expiresAt: createdAt.add(const Duration(days: 366)),
      ),
      throwsA(
        isA<MemoryGovernanceException>().having(
          (MemoryGovernanceException error) => error.code,
          'code',
          'invalid_expiry',
        ),
      ),
    );
  });

  test('receipt exposes governance fields and user controls', () {
    final DateTime createdAt = DateTime.utc(2026, 8, 20, 12);
    final MemoryEntity memory = _governed(
      accountScopeId: 'v2.account-a',
      surface: MemorySurface.smartPlanner,
      createdAt: createdAt,
    );
    final Map<String, dynamic> receipt = memory.toReceipt().toJson();

    expect(receipt['storedText'], memory.text);
    expect(receipt['whyStored'], memory.whyStored);
    expect(receipt['sourceSurface'], 'smartPlanner');
    expect(receipt['purpose'], 'guidancePreference');
    expect(receipt['consentStatus'], 'granted');
    expect(receipt['expiresAt'], isNotNull);
    expect(receipt['controls'], <String>[
      'view',
      'correct',
      'export',
      'delete',
    ]);
    expect(receipt, isNot(contains('accountScopeId')));
  });

  test('ten thousand randomized recalls never cross account or surface', () {
    final Random random = Random(8242026);
    final DateTime now = DateTime.utc(2026, 8, 20, 12);
    const List<MemorySurface> storableSurfaces = <MemorySurface>[
      MemorySurface.smartPlanner,
      MemorySurface.creator,
      MemorySurface.settings,
    ];
    const List<MemorySurface> requestSurfaces = <MemorySurface>[
      MemorySurface.smartPlanner,
      MemorySurface.creator,
      MemorySurface.settings,
      MemorySurface.siConsole,
    ];

    for (int index = 0; index < 10000; index++) {
      final String owner = 'v2.account-${random.nextInt(50)}';
      final MemorySurface source =
          storableSurfaces[random.nextInt(storableSurfaces.length)];
      final MemoryEntity memory = _governed(
        accountScopeId: owner,
        surface: source,
        createdAt: now,
      );
      final String requester = 'v2.account-${random.nextInt(50)}';
      final MemorySurface request =
          requestSurfaces[random.nextInt(requestSurfaces.length)];
      final bool expected = requester == owner && request == source;

      expect(
        memory.canBeRetrieved(
          requestingAccountScopeId: requester,
          requestingSurface: request,
          now: now,
        ),
        expected,
        reason:
            'owner=$owner requester=$requester source=$source request=$request',
      );
    }
  });

  test('withdrawn, expired, emotional, and SI memory never retrieve', () {
    final DateTime now = DateTime.utc(2026, 8, 20, 12);
    final MemoryEntity base = _governed(
      accountScopeId: 'v2.account-a',
      surface: MemorySurface.smartPlanner,
      createdAt: now,
    );
    bool recalls(MemoryEntity memory, MemorySurface surface) =>
        memory.canBeRetrieved(
          requestingAccountScopeId: 'v2.account-a',
          requestingSurface: surface,
          now: now,
        );

    expect(
      recalls(
        base.copyWith(consentStatus: MemoryConsentStatus.withdrawn),
        MemorySurface.smartPlanner,
      ),
      isFalse,
    );
    expect(
      base.canBeRetrieved(
        requestingAccountScopeId: 'v2.account-a',
        requestingSurface: MemorySurface.smartPlanner,
        now: now.add(const Duration(days: 91)),
      ),
      isFalse,
    );
    expect(
      recalls(
        base.copyWith(sensitivity: MemorySensitivity.emotional),
        MemorySurface.smartPlanner,
      ),
      isFalse,
    );
    expect(recalls(base, MemorySurface.siConsole), isFalse);
  });
}

MemoryEntity _governed({
  required String accountScopeId,
  required MemorySurface surface,
  required DateTime createdAt,
}) {
  return MemoryEntity(
    id: 'preference',
    text: 'Prefer one small next step.',
    date: createdAt,
    accountScopeId: accountScopeId,
    sourceSurface: surface,
    purpose: MemoryPurpose.guidancePreference,
    sensitivity: MemorySensitivity.personal,
    consentStatus: MemoryConsentStatus.granted,
    consentedAt: createdAt,
    expiresAt: createdAt.add(const Duration(days: 90)),
    provenance: 'User-entered preference dialog.',
    whyStored: 'Adapt same-surface guidance.',
  );
}
