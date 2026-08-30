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

  test('malformed data is preserved before a replacement write', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    store.values[repository.storageKey!] = '{not-json';

    expect((await repository.load()).signals, isEmpty);
    await repository.upsert(signal('replacement'));

    expect(store.values[repository.corruptionKey!], '{not-json');
    final Map<String, dynamic> decoded =
        jsonDecode(store.values[repository.storageKey!]!)
            as Map<String, dynamic>;
    expect(decoded['signals'], hasLength(1));
  });

  test('an existing different corruption backup blocks overwrite', () async {
    final _MemoryStore store = _MemoryStore();
    final PersonContextRepository repository = PersonContextRepository(
      store,
      scope,
      clock: () => now,
    );
    store.values[repository.storageKey!] = '{new-corruption';
    store.values[repository.corruptionKey!] = '{older-corruption';

    await repository.load();
    await expectLater(repository.upsert(signal('blocked')), throwsStateError);
    expect(store.values[repository.storageKey!], '{new-corruption');
  });

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
