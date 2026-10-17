import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

const _localA = User.localProfile(
  id: 'local-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: '  Chosen local name  ',
);
const _localB = User.localProfile(
  id: 'local-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  displayName: 'Second local name',
);

String _seeded(String localName) =>
    Env.isLocalMode ? localName : 'Axiomara User';

String _profileKey(String id) =>
    AccountStorageNamespace.authenticated(id).scopedKey('profile_state_v2');

void main() {
  late Directory directory;

  setUp(() async {
    await Hive.close();
    directory = await Directory.systemTemp.createTemp('profile_local_name_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'fresh named local profile seeds only after storage readiness',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.activate(_localA, ready: false);
      expect(
        fixture.container.read(accountStorageScopeProvider).isWritable,
        false,
      );
      expect(fixture.state.name, 'Axiomara User');
      expect(fixture.backend.writes, isEmpty);

      fixture.completeBoundary();
      await fixture.waitFor(ProfileReadStatus.ready);
      expect(fixture.state.name, _seeded('Chosen local name'));
      expect(fixture.state.xp, 0);
      expect(fixture.state.level, 1);
      expect(fixture.state.legacyLevelFloor, 1);
      expect(
        fixture.backend.writes,
        isEmpty,
        reason: 'seeding adds no profile write during hydration',
      );

      await fixture.container.read(profileProvider.notifier).toggleSound(false);
      final stored =
          jsonDecode(
                (await fixture.backend.read(key: _profileKey(_localA.id)))!,
              )
              as Map<String, dynamic>;
      expect(stored['name'], _seeded('Chosen local name'));
      expect(stored['soundEnabled'], false);
    },
  );

  test(
    'blank local name and cloud identity retain the built-in default',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.activate(
        const User.localProfile(
          id: 'local-cccccccccccccccccccccccccccccccc',
          displayName: '   ',
        ),
      );
      await fixture.waitFor(ProfileReadStatus.ready);
      expect(fixture.state.name, 'Axiomara User');
      await fixture.activate(
        const User(
          id: 'cloud-person',
          displayName: 'Cloud display name',
          emailVerified: true,
        ),
      );
      await fixture.waitFor(ProfileReadStatus.ready);
      expect(fixture.state.name, 'Axiomara User');
      expect(fixture.backend.writes, isEmpty);
    },
  );

  for (final savedName in ['Saved custom name', 'Axiomara User']) {
    test(
      'existing payload "$savedName" and earned progress always win',
      () async {
        final backend = _Backend();
        final saved = ProfileState(
          name: savedName,
          xp: 925,
          level: 7,
          legacyLevelFloor: 7,
          streak: 8,
          longestStreak: 12,
          soundEnabled: false,
          xpBySource: const {'task_completion': 925},
        );
        final raw = jsonEncode(saved.toJson());
        await backend.write(key: _profileKey(_localA.id), value: raw);
        backend.writes.clear();
        final fixture = _Fixture(backend: backend);
        addTearDown(fixture.dispose);
        await fixture.activate(_localA);
        await fixture.waitFor(ProfileReadStatus.ready);
        expect(
          fixture.state.toJson(),
          ProfileState.fromJson(saved.toJson()).toJson(),
        );
        expect(await backend.read(key: _profileKey(_localA.id)), raw);
        expect(backend.writes, isEmpty);
      },
    );
  }

  test(
    'owned legacy profile is restored rather than treated as missing',
    () async {
      final legacy = await Hive.openBox<String>(HiveBoxes.profile);
      final saved = ProfileState(
        name: 'Preserved legacy name',
        xp: 700,
        level: 5,
        legacyLevelFloor: 5,
        streak: 4,
      );
      final raw = jsonEncode(saved.toJson());
      await legacy.put('profile_state', raw);
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.activate(
        _localA,
        ownership: LegacyScopeOwnership.provenOwned,
      );
      await fixture.waitFor(ProfileReadStatus.ready);
      expect(
        fixture.state.toJson(),
        ProfileState.fromJson(saved.toJson()).toJson(),
      );
      expect(await fixture.backend.read(key: _profileKey(_localA.id)), raw);
      expect(legacy.get('profile_state'), raw);
    },
  );

  test(
    'a storage read failure remains unavailable and is never seeded over',
    () async {
      final backend = _Backend()..failingKey = _profileKey(_localA.id);
      final fixture = _Fixture(backend: backend);
      addTearDown(fixture.dispose);
      await fixture.activate(_localA);
      await fixture.waitFor(ProfileReadStatus.unavailable);
      expect(fixture.state.name, 'Axiomara User');
      expect(backend.writes, isEmpty);
    },
  );

  test('A to B to A preserves independent saved public names', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.activate(_localA);
    await fixture.waitFor(ProfileReadStatus.ready);
    expect(fixture.state.name, _seeded('Chosen local name'));
    await fixture.container
        .read(profileProvider.notifier)
        .updateName('Saved A');

    await fixture.activate(_localB);
    await fixture.waitFor(ProfileReadStatus.ready);
    expect(fixture.state.name, _seeded('Second local name'));
    await fixture.container
        .read(profileProvider.notifier)
        .updateName('Saved B');

    await fixture.activate(
      User.localProfile(id: _localA.id, displayName: 'Changed auth-side name'),
    );
    await fixture.waitFor(ProfileReadStatus.ready);
    expect(fixture.state.name, 'Saved A');
    final a =
        jsonDecode((await fixture.backend.read(key: _profileKey(_localA.id)))!)
            as Map<String, dynamic>;
    final b =
        jsonDecode((await fixture.backend.read(key: _profileKey(_localB.id)))!)
            as Map<String, dynamic>;
    expect(a['name'], 'Saved A');
    expect(b['name'], 'Saved B');
  });

  test('late A hydration cannot seed the visible B profile', () async {
    final backend = _Backend()..blockedKey = _profileKey(_localA.id);
    final fixture = _Fixture(backend: backend);
    addTearDown(fixture.dispose);
    await fixture.activate(_localA);
    await backend.readStarted.future.timeout(const Duration(seconds: 5));
    await fixture.activate(_localB);
    await fixture.waitFor(ProfileReadStatus.ready);
    expect(fixture.state.name, _seeded('Second local name'));
    backend.releaseRead();
    await pumpEventQueue();
    expect(
      fixture.container.read(accountStorageScopeProvider).rawUserId,
      _localB.id,
    );
    expect(fixture.state.name, _seeded('Second local name'));
    expect(backend.writes, isEmpty);
  });
}

class _Fixture {
  _Fixture({_Backend? backend}) : backend = backend ?? _Backend() {
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: this.backend),
        ),
        hiveStoreProvider.overrideWithValue(_DirectHiveStore()),
        authUserProvider.overrideWith((ref) => _auth.stream),
      ],
    );
    _subscription = container.listen<ProfileState>(profileProvider, (_, _) {});
  }

  final _Backend backend;
  final _auth = StreamController<User?>.broadcast(sync: true);
  late final ProviderContainer container;
  late final ProviderSubscription<ProfileState> _subscription;
  int _generation = 0;
  LegacyScopeOwnership _ownership = LegacyScopeOwnership.ambiguous;
  bool _disposed = false;

  ProfileState get state => container.read(profileProvider);

  Future<void> activate(
    User user, {
    bool ready = true,
    LegacyScopeOwnership ownership = LegacyScopeOwnership.ambiguous,
  }) async {
    _ownership = ownership;
    _generation = container
        .read(authSessionBoundaryProvider.notifier)
        .begin(userId: user.id, isTransitioning: true);
    await pumpEventQueue();
    _auth.add(user);
    await pumpEventQueue();
    if (ready) completeBoundary();
    await pumpEventQueue();
  }

  void completeBoundary() {
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    boundary.markStorageReady(_generation, legacyOwnership: _ownership);
    boundary.complete(_generation);
  }

  Future<void> waitFor(ProfileReadStatus expected) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await pumpEventQueue();
      if (container.read(accountStorageScopeProvider).isWritable &&
          state.readStatus == expected) {
        return;
      }
    }
    throw StateError('Expected settled profile read status was not reached.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    backend.releaseRead();
    _subscription.close();
    container.dispose();
    await _auth.close();
  }
}

class _Backend extends InMemorySecureStoreBackend {
  final writes = <String>[];
  String? failingKey;
  String? blockedKey;
  final readStarted = Completer<void>();
  final _readGate = Completer<void>();

  void releaseRead() {
    if (!_readGate.isCompleted) _readGate.complete();
  }

  @override
  Future<String?> read({required String key}) async {
    if (key == failingKey) throw StateError('Simulated profile read failure');
    if (key == blockedKey) {
      if (!readStarted.isCompleted) readStarted.complete();
      await _readGate.future;
    }
    return super.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes.add(key);
    await super.write(key: key, value: value);
  }
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) async => Hive.openBox<T>(key);
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async {
    await (await openBox<dynamic>(key)).clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<dynamic>(key).close();
  }
}
