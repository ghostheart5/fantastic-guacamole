import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/person_context_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 30, 12);
  final AccountStorageScope scope = AccountStorageScope.authenticated(
    'account-a',
  );

  PersonContextSignal signal(String id) => PersonContextSignal(
    id: id,
    kind: PersonContextKind.currentPriority,
    value: 'Finish the release safely',
    source: PersonContextSource.userAuthored,
    consent: PersonContextConsent.granted,
    consentedAt: now,
    purpose: PersonContextPurpose.planningGuidance,
    surfaceScopes: const <PersonContextSurface>{
      PersonContextSurface.smartPlanner,
      PersonContextSurface.nexus,
    },
    recordedAt: now,
    freshUntil: now.add(const Duration(days: 7)),
    expiresAt: now.add(const Duration(days: 30)),
    exportBehavior: PersonContextExportBehavior.include,
    deletionBehavior: PersonContextDeletionBehavior.userRemovable,
  );

  test('persists and loads only the exact account scope', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    await repository.upsert(signal('priority'));

    final PersonContextSpine loaded = await repository.load();
    expect(loaded.accountScopeId, scope.v2Namespace);
    expect(loaded.signals.single.id, 'priority');

    final PersonContextRepository other = PersonContextRepository(
      store,
      AccountStorageScope.authenticated('account-b'),
      clock: () => now,
    );
    expect((await other.load()).signals, isEmpty);
  });

  test('direct save initializes storage before writing', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    await repository.save(
      PersonContextSpine(
        accountScopeId: scope.v2Namespace!,
        updatedAt: now,
        signals: <PersonContextSignal>[signal('priority')],
      ),
    );

    expect(store.initialized, isTrue);
    expect(store.values[repository.storageKey!], isNotNull);
  });

  test('malformed data is preserved and blocks a replacement write', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    store.values[repository.storageKey!] = '{not-json';

    await expectLater(
      repository.load(),
      throwsA(isA<PersonContextCorruptionException>()),
    );
    expect(store.values[repository.corruptionKey!], '{not-json');
    await expectLater(
      repository.upsert(signal('replacement')),
      throwsA(isA<PersonContextCorruptionException>()),
    );
    expect(store.values[repository.storageKey!], '{not-json');
  });

  test(
    'whitespace corruption is preserved instead of treated as empty',
    () async {
      final _MemoryStore store = _MemoryStore();
      final PersonContextRepository repository = PersonContextRepository(
        store,
        scope,
        clock: () => now,
      );
      store.values[repository.storageKey!] = '   ';

      await expectLater(
        repository.load(),
        throwsA(isA<PersonContextCorruptionException>()),
      );
      expect(store.values[repository.corruptionKey!], '   ');
      expect(store.values[repository.storageKey!], '   ');
    },
  );

  test('an existing different corruption backup blocks overwrite', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    store.values[repository.storageKey!] = '{new-corruption';
    store.values[repository.corruptionKey!] = '{older-corruption';

    await expectLater(repository.load(), throwsStateError);
    expect(store.values[repository.storageKey!], '{new-corruption');
  });

  test('automatic expiry removes the signal from storage and export', () async {
    final _MemoryStore store = _MemoryStore();
    DateTime clock = now;
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => clock,
    );
    final PersonContextSignal expiring = PersonContextSignal(
      id: 'capacity',
      kind: PersonContextKind.presentCapacity,
      value: 'Low energy right now',
      source: PersonContextSource.userAuthored,
      consent: PersonContextConsent.granted,
      consentedAt: now,
      purpose: PersonContextPurpose.planningGuidance,
      surfaceScopes: const <PersonContextSurface>{
        PersonContextSurface.smartPlanner,
      },
      recordedAt: now,
      freshUntil: now.add(const Duration(hours: 1)),
      expiresAt: now.add(const Duration(hours: 2)),
      exportBehavior: PersonContextExportBehavior.include,
      deletionBehavior: PersonContextDeletionBehavior.expiresAutomatically,
    );
    await repository.upsert(expiring);
    clock = now.add(const Duration(hours: 3));

    expect((await repository.load()).signals, isEmpty);
    expect((await repository.export())['signals'], isEmpty);
    final Map<String, dynamic> stored =
        jsonDecode(store.values[repository.storageKey!]!)
            as Map<String, dynamic>;
    expect(stored['signals'], isEmpty);
  });

  test('an account transition blocks a queued stale write', () async {
    final _MemoryStore store = _MemoryStore();
    bool current = true;
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
      isScopeCurrent: () => current,
    );
    current = false;

    await expectLater(repository.upsert(signal('stale')), throwsStateError);
    expect(store.values[repository.storageKey!], isNull);
  });

  test(
    'repository instances serialize writes without losing signals',
    () async {
      final _MemoryStore store = _MemoryStore();
      final PersonContextRepository first = PersonContextRepository(
        store,
        scope,
        clock: () => now,
      );
      final PersonContextRepository second = PersonContextRepository(
        store,
        scope,
        clock: () => now,
      );

      await Future.wait(<Future<void>>[
        first.upsert(signal('first')),
        second.upsert(signal('second')),
      ]);

      expect(
        (await first.load()).signals.map((item) => item.id),
        containsAll(<String>['first', 'second']),
      );
    },
  );

  test(
    'ordered corrections and consent withdrawal cannot roll each other back',
    () async {
      final _MemoryStore store = _MemoryStore();
      final PersonContextRepository repository = PersonContextRepository(
        store,
        scope,
        clock: () => now.add(const Duration(minutes: 3)),
      );
      await repository.upsert(signal('ordered'));
      await repository.updateSignal(
        'ordered',
        (PersonContextSignal current) => current.corrected(
          value: 'Finish the verified release safely',
          correctedAt: now.add(const Duration(minutes: 1)),
          reason: 'Clarified the exact priority',
          freshUntil: now.add(const Duration(days: 7)),
          expiresAt: now.add(const Duration(days: 30)),
        ),
      );
      await repository.updateSignal(
        'ordered',
        (PersonContextSignal current) =>
            current.withdrawConsent(now.add(const Duration(minutes: 2))),
      );

      PersonContextSignal stored = (await repository.load()).signals.single;
      expect(stored.value, 'Finish the verified release safely');
      expect(stored.corrections, hasLength(1));
      expect(stored.consent, PersonContextConsent.withdrawn);

      await repository.upsert(signal('reverse'));
      await repository.updateSignal(
        'reverse',
        (PersonContextSignal current) =>
            current.withdrawConsent(now.add(const Duration(minutes: 1))),
      );
      await repository.updateSignal(
        'reverse',
        (PersonContextSignal current) => current.corrected(
          value: 'Corrected while withdrawn',
          correctedAt: now.add(const Duration(minutes: 2)),
          reason: 'The stored text was inaccurate',
          freshUntil: now.add(const Duration(days: 7)),
          expiresAt: now.add(const Duration(days: 30)),
        ),
      );

      stored = (await repository.load()).signals.singleWhere(
        (PersonContextSignal item) => item.id == 'reverse',
      );
      expect(stored.value, 'Corrected while withdrawn');
      expect(stored.consent, PersonContextConsent.withdrawn);
    },
  );

  test('export obeys per-signal export behavior', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    await repository.upsert(signal('included'));
    final PersonContextSignal excluded = PersonContextSignal(
      id: 'excluded',
      kind: PersonContextKind.boundary,
      value: 'Do not export this',
      source: PersonContextSource.userAuthored,
      consent: PersonContextConsent.granted,
      consentedAt: now,
      purpose: PersonContextPurpose.decisionSupport,
      surfaceScopes: const <PersonContextSurface>{PersonContextSurface.nexus},
      recordedAt: now,
      freshUntil: now.add(const Duration(days: 1)),
      expiresAt: now.add(const Duration(days: 2)),
      exportBehavior: PersonContextExportBehavior.exclude,
      deletionBehavior: PersonContextDeletionBehavior.userRemovable,
    );
    await repository.upsert(excluded);

    final Map<String, dynamic> exported = await repository.export();
    expect(exported['accountScopeId'], isNull);
    expect(exported['exportedAt'], now.toIso8601String());
    expect(exported['signals'], hasLength(1));
  });

  test('unsafe or signed-out scopes cannot read or write', () async {
    for (final AccountStorageScope unavailable in <AccountStorageScope>[
      const AccountStorageScope.signedOut(),
      const AccountStorageScope.unsafe(),
    ]) {
      final PersonContextRepository repository = PersonContextRepository(
        _MemoryStore(),
        unavailable,
      );
      await expectLater(repository.load(), throwsStateError);
      await expectLater(repository.upsert(signal('blocked')), throwsStateError);
      await expectLater(repository.export(), throwsStateError);
    }
  });
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};
  bool initialized = false;

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async => values.clear();
}
