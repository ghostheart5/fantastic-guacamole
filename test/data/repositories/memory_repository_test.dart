import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/memory_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime base = DateTime.utc(2026, 8, 20, 12);

  test('returns paged governed memories newest first', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'account-a',
    );
    final MemoryRepository repository = MemoryRepository(
      store,
      scope,
      clock: () => base,
    );
    for (int index = 1; index <= 3; index++) {
      await repository.saveMemory(
        _memory(
          id: 'memory-$index',
          text: 'Preference $index',
          createdAt: base.add(Duration(minutes: index)),
          accountScopeId: scope.v2Namespace!,
        ),
      );
    }

    final firstPage = repository.getMemoriesPage(limit: 2);
    final secondPage = repository.getMemoriesPage(
      cursor: firstPage.nextCursor,
      limit: 2,
    );

    expect(firstPage.items.map((MemoryEntity memory) => memory.id), <String>[
      'memory-3',
      'memory-2',
    ]);
    expect(firstPage.nextCursor, 'memory-2');
    expect(secondPage.items.single.id, 'memory-1');
    expect(secondPage.nextCursor, isNull);
  });

  test('isolates accounts and product surfaces exactly', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope accountA = AccountStorageScope.authenticated(
      'account-a',
    );
    final AccountStorageScope accountB = AccountStorageScope.authenticated(
      'account-b',
    );
    final MemoryRepository repositoryA = MemoryRepository(
      store,
      accountA,
      clock: () => base,
    );
    final MemoryRepository repositoryB = MemoryRepository(
      store,
      accountB,
      clock: () => base,
    );

    await repositoryA.saveMemory(
      _memory(
        id: 'planner-a',
        text: 'Planner A',
        createdAt: base,
        accountScopeId: accountA.v2Namespace!,
      ),
    );
    await repositoryA.saveMemory(
      _memory(
        id: 'creator-a',
        text: 'Creator A',
        createdAt: base,
        accountScopeId: accountA.v2Namespace!,
        surface: MemorySurface.creator,
      ),
    );
    await repositoryB.saveMemory(
      _memory(
        id: 'planner-b',
        text: 'Planner B',
        createdAt: base,
        accountScopeId: accountB.v2Namespace!,
      ),
    );

    expect(
      repositoryA
          .getMemoriesForSurface(MemorySurface.smartPlanner)
          .map((MemoryEntity memory) => memory.id),
      <String>['planner-a'],
    );
    expect(
      repositoryA
          .getMemoriesForSurface(MemorySurface.creator)
          .map((MemoryEntity memory) => memory.id),
      <String>['creator-a'],
    );
    expect(
      repositoryB.getMemoriesForSurface(MemorySurface.smartPlanner).single.id,
      'planner-b',
    );
    expect(repositoryA.getMemoriesForSurface(MemorySurface.siConsole), isEmpty);
  });

  test('signed-out and unsafe scopes fail closed', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope owner = AccountStorageScope.authenticated(
      'account-a',
    );
    final MemoryEntity memory = _memory(
      id: 'owned',
      text: 'Owned preference',
      createdAt: base,
      accountScopeId: owner.v2Namespace!,
    );
    final MemoryRepository signedOut = MemoryRepository(
      store,
      const AccountStorageScope.signedOut(),
      clock: () => base,
    );
    final MemoryRepository unsafe = MemoryRepository(
      store,
      const AccountStorageScope.unsafe(),
      clock: () => base,
    );

    expect(signedOut.getMemories(), isEmpty);
    expect(unsafe.getMemories(), isEmpty);
    await expectLater(signedOut.saveMemory(memory), throwsStateError);
    await expectLater(unsafe.deleteMemory(memory.id), throwsStateError);
  });

  test('preserves and never adopts ambiguous global legacy memory', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    await store.save(
      MemoryRepository.legacyGlobalKey,
      jsonEncode(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'legacy',
          'text': 'Unknown owner',
          'date': base.toIso8601String(),
        },
      ]),
    );
    final MemoryRepository repository = MemoryRepository(
      store,
      AccountStorageScope.authenticated('account-a'),
      clock: () => base,
    );

    expect(repository.getMemories(), isEmpty);
    expect(store.load(MemoryRepository.legacyGlobalKey), isNotNull);
  });

  test('rejects unconsented and SI durable records', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'account-a',
    );
    final MemoryRepository repository = MemoryRepository(
      store,
      scope,
      clock: () => base,
    );
    final MemoryEntity unconsented = _memory(
      id: 'unconsented',
      text: 'No consent',
      createdAt: base,
      accountScopeId: scope.v2Namespace!,
    ).copyWith(consentStatus: MemoryConsentStatus.legacyUnverified);
    final MemoryEntity siMemory = _memory(
      id: 'si',
      text: 'SI interpretation',
      createdAt: base,
      accountScopeId: scope.v2Namespace!,
      surface: MemorySurface.siConsole,
    );

    await expectLater(repository.saveMemory(unconsented), throwsStateError);
    await expectLater(repository.saveMemory(siMemory), throwsStateError);
  });

  test('tampered sensitive records fail closed and are purged', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'account-a',
    );
    final MemoryRepository repository = MemoryRepository(
      store,
      scope,
      clock: () => base,
    );
    final Map<String, dynamic> tampered = _memory(
      id: 'tampered',
      text: 'Raw emotional disclosure',
      createdAt: base,
      accountScopeId: scope.v2Namespace!,
    ).toJson();
    tampered['sensitivity'] = MemorySensitivity.emotional.name;
    await store.save(repository.storageKey!, jsonEncode(<Object>[tampered]));

    expect(repository.getMemories(), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(
      jsonDecode(store.load(repository.storageKey!)!) as List<dynamic>,
      isEmpty,
    );
  });

  test('expired and deleted memories are never retrieved', () async {
    DateTime now = base;
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'account-a',
    );
    final MemoryRepository repository = MemoryRepository(
      store,
      scope,
      clock: () => now,
    );
    await repository.saveMemory(
      _memory(
        id: 'expiring',
        text: 'Short retention',
        createdAt: base,
        accountScopeId: scope.v2Namespace!,
        expiresAt: base.add(const Duration(days: 1)),
      ),
    );
    expect(repository.getMemories(), hasLength(1));

    now = base.add(const Duration(days: 2));
    expect(repository.getMemories(), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(
      jsonDecode(store.load(repository.storageKey!)!) as List<dynamic>,
      isEmpty,
    );

    now = base.add(const Duration(days: 2));
    await repository.saveMemory(
      _memory(
        id: 'deletable',
        text: 'Delete me',
        createdAt: now,
        accountScopeId: scope.v2Namespace!,
      ),
    );
    await repository.deleteMemory('deletable');
    expect(repository.getMemories(), isEmpty);
  });

  test('concurrent consented saves never lose a memory', () async {
    final _InMemorySharedPrefsStore store = _InMemorySharedPrefsStore();
    final AccountStorageScope scope = AccountStorageScope.authenticated(
      'account-a',
    );
    final MemoryRepository repository = MemoryRepository(
      store,
      scope,
      clock: () => base,
    );

    await Future.wait(<Future<void>>[
      for (int index = 0; index < 100; index++)
        repository.saveMemory(
          _memory(
            id: 'concurrent-$index',
            text: 'Preference $index',
            createdAt: base.add(Duration(microseconds: index)),
            accountScopeId: scope.v2Namespace!,
          ),
        ),
    ]);

    expect(repository.getMemories(), hasLength(100));
    expect(
      repository.getMemories().map((MemoryEntity memory) => memory.id).toSet(),
      hasLength(100),
    );
  });
}

MemoryEntity _memory({
  required String id,
  required String text,
  required DateTime createdAt,
  required String accountScopeId,
  MemorySurface surface = MemorySurface.smartPlanner,
  DateTime? expiresAt,
}) {
  return MemoryEntity(
    id: id,
    text: text,
    date: createdAt,
    category: MemoryCategory.planningGuidancePreference,
    accountScopeId: accountScopeId,
    sourceSurface: surface,
    purpose: MemoryPurpose.guidancePreference,
    sensitivity: MemorySensitivity.personal,
    consentStatus: MemoryConsentStatus.granted,
    consentedAt: createdAt,
    expiresAt: expiresAt ?? createdAt.add(const Duration(days: 90)),
    provenance: 'test explicit consent dialog',
    whyStored: 'Test future same-surface guidance.',
  );
}

class _InMemorySharedPrefsStore implements SharedPrefsStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> clear() async => _values.clear();

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => _values[key];

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }
}
