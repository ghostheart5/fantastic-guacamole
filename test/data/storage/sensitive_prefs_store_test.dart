import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/sensitive_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const String storageKey = 'sensitive_preferences_v1';
  const String corruptBackupKey = 'sensitive_preferences_v1_corrupt_backups';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SensitivePrefsStore> build(_MemorySensitiveBackend backend) async {
    final SensitivePrefsStore store = SensitivePrefsStore.forTesting(
      backend: backend,
      legacyPreferences: SharedPreferences.getInstance,
    );
    return store;
  }

  test(
    'malformed container is preserved before active data is cleared',
    () async {
      final _MemorySensitiveBackend backend = _MemorySensitiveBackend()
        ..values[storageKey] = 'not-json';
      final SensitivePrefsStore store = await build(backend);

      await store.init();

      expect(store.recoveredCorruption, isTrue);
      expect(backend.values[storageKey], isNull);
      expect(
        jsonDecode(backend.values[corruptBackupKey]!) as List<dynamic>,
        <String>['not-json'],
      );
      expect(await store.keys(), isEmpty);
    },
  );

  test('non-string container values are preserved as corruption', () async {
    final String raw = jsonEncode(<String, Object>{'timeline': 42});
    final _MemorySensitiveBackend backend = _MemorySensitiveBackend()
      ..values[storageKey] = raw;
    final SensitivePrefsStore store = await build(backend);

    await store.init();

    expect(store.recoveredCorruption, isTrue);
    expect(store.hasCorruptionBackups, isTrue);
    expect(
      jsonDecode(backend.values[corruptBackupKey]!) as List<dynamic>,
      <String>[raw],
    );
  });

  test('failed corruption backup leaves the active payload intact', () async {
    final _MemorySensitiveBackend backend = _MemorySensitiveBackend(
      failingWriteKey: corruptBackupKey,
    )..values[storageKey] = 'not-json';
    final SensitivePrefsStore store = await build(backend);

    await expectLater(store.init(), throwsStateError);

    expect(backend.values[storageKey], 'not-json');
    expect(backend.values[corruptBackupKey], isNull);
    expect(store.recoveredCorruption, isFalse);
  });

  test(
    'legacy migration persists securely before removing legacy data',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'timeline_events_v1': '[{"id":"legacy"}]',
      });
      final _MemorySensitiveBackend backend = _MemorySensitiveBackend(
        failingWriteKey: storageKey,
      );
      final SensitivePrefsStore store = await build(backend);

      await expectLater(store.init(), throwsStateError);

      final SharedPreferences legacy = await SharedPreferences.getInstance();
      expect(legacy.getString('timeline_events_v1'), '[{"id":"legacy"}]');
    },
  );

  test('serialized mutations retain both values', () async {
    final _MemorySensitiveBackend backend = _MemorySensitiveBackend();
    final SensitivePrefsStore store = await build(backend);

    await Future.wait<void>(<Future<void>>[
      store.save('first', 'one'),
      store.save('second', 'two'),
    ]);

    expect(store.load('first'), 'one');
    expect(store.load('second'), 'two');
    expect(
      jsonDecode(backend.values[storageKey]!) as Map<String, dynamic>,
      <String, dynamic>{'first': 'one', 'second': 'two'},
    );
  });

  test('failed mutation restores the in-memory snapshot', () async {
    final _MemorySensitiveBackend backend = _MemorySensitiveBackend();
    final SensitivePrefsStore store = await build(backend);
    await store.save('stable', 'value');
    backend.failingWriteKey = storageKey;

    await expectLater(store.save('failed', 'value'), throwsStateError);

    expect(store.load('stable'), 'value');
    expect(store.load('failed'), isNull);
  });

  test('clear removes active and preserved corruption payloads', () async {
    final _MemorySensitiveBackend backend = _MemorySensitiveBackend()
      ..values[storageKey] = jsonEncode(<String, String>{'stable': 'value'})
      ..values[corruptBackupKey] = jsonEncode(<String>['old-corruption']);
    final SensitivePrefsStore store = await build(backend);
    await store.init();

    await store.clear();

    expect(backend.values[storageKey], isNull);
    expect(backend.values[corruptBackupKey], isNull);
    expect(await store.keys(), isEmpty);
    expect(store.hasCorruptionBackups, isFalse);
  });

  test('failed active clear preserves the corruption backup', () async {
    final _MemorySensitiveBackend backend =
        _MemorySensitiveBackend(failingDeleteKey: storageKey)
          ..values[storageKey] = jsonEncode(<String, String>{'stable': 'value'})
          ..values[corruptBackupKey] = jsonEncode(<String>['old-corruption']);
    final SensitivePrefsStore store = await build(backend);
    await store.init();

    await expectLater(store.clear(), throwsStateError);

    expect(backend.values[storageKey], isNotNull);
    expect(backend.values[corruptBackupKey], isNotNull);
    expect(store.load('stable'), 'value');
    expect(store.hasCorruptionBackups, isTrue);
  });

  test('failed backup clear keeps the backup discoverable', () async {
    final _MemorySensitiveBackend backend =
        _MemorySensitiveBackend(failingDeleteKey: corruptBackupKey)
          ..values[storageKey] = jsonEncode(<String, String>{'stable': 'value'})
          ..values[corruptBackupKey] = jsonEncode(<String>['old-corruption']);
    final SensitivePrefsStore store = await build(backend);
    await store.init();

    await expectLater(store.clear(), throwsStateError);

    expect(backend.values[storageKey], isNull);
    expect(backend.values[corruptBackupKey], isNotNull);
    expect(await store.keys(), isEmpty);
    expect(store.hasCorruptionBackups, isTrue);
  });
}

class _MemorySensitiveBackend implements SensitiveStorageBackend {
  _MemorySensitiveBackend({this.failingWriteKey, this.failingDeleteKey});

  final Map<String, String> values = <String, String>{};
  String? failingWriteKey;
  String? failingDeleteKey;

  @override
  Future<void> delete(String key) async {
    if (key == failingDeleteKey) {
      throw StateError('delete failed');
    }
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (key == failingWriteKey) {
      throw StateError('write failed');
    }
    values[key] = value;
  }
}
