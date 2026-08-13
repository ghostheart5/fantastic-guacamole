import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(FirebaseSupabaseBridgeRepository.resumeSessionWrites);

  test('serializes cache writes in FIFO order', () async {
    final _Backend backend = _Backend()..holdFirstWrite = true;
    final FirebaseSupabaseBridgeRepository bridge = _bridge(backend);

    final Future<void> first = bridge.cacheFirebaseMessagingToken('first');
    final Future<void> second = bridge.cacheFirebaseMessagingToken('second');
    await Future<void>.delayed(Duration.zero);
    expect(backend.writeValues, isEmpty);

    backend.releaseFirstWrite();
    await Future.wait<void>(<Future<void>>[first, second]);
    expect(backend.writeValues, <String>['first', 'second']);
  });

  test('a failed mutation does not poison later queued work', () async {
    final _Backend backend = _Backend()..failNextWrite = true;
    final FirebaseSupabaseBridgeRepository bridge = _bridge(backend);

    await expectLater(
      bridge.cacheFirebaseMessagingToken('bad'),
      throwsStateError,
    );
    await bridge.cacheFirebaseMessagingToken('good');

    expect(backend.values['bridge.firebase_messaging_token'], 'good');
  });

  test(
    'suspension skips writes without replay and resume permits new writes',
    () async {
      final _Backend backend = _Backend();
      final FirebaseSupabaseBridgeRepository bridge = _bridge(backend);

      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      await bridge.cacheFirebaseMessagingToken('skipped');
      FirebaseSupabaseBridgeRepository.resumeSessionWrites();
      await bridge.drainMutations();
      expect(backend.writeValues, isEmpty);

      await bridge.cacheFirebaseMessagingToken('accepted');
      expect(backend.writeValues, <String>['accepted']);
    },
  );

  test(
    'drain waits for pending work and repeated gate calls are safe',
    () async {
      final _Backend backend = _Backend()..holdFirstWrite = true;
      final FirebaseSupabaseBridgeRepository bridge = _bridge(backend);

      final Future<void> mutation = bridge.cacheFirebaseMessagingToken(
        'queued',
      );
      final Future<void> drain = bridge.drainMutations();
      var completed = false;
      unawaited(drain.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      backend.releaseFirstWrite();
      await mutation;
      await drain;
      expect(completed, isTrue);

      FirebaseSupabaseBridgeRepository.resumeSessionWrites();
      FirebaseSupabaseBridgeRepository.resumeSessionWrites();
      await bridge.cacheFirebaseMessagingToken('resumed');
      expect(backend.writeValues, contains('resumed'));
    },
  );

  test('candidate contains identity checks for sync and disassociation', () {
    final String source = File(
      'lib/data/repositories/firebase_supabase_bridge_repository.dart',
    ).readAsStringSync();
    expect(source, contains('final String? expectedUserId'));
    expect(source, contains('user?.id == expectedUserId'));
    expect(source, contains('client.auth.currentUser?.id != expectedUserId'));
  });
}

FirebaseSupabaseBridgeRepository _bridge(_Backend backend) {
  return FirebaseSupabaseBridgeRepository(store: SecureStore(backend: backend));
}

class _Backend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  final List<String> writeValues = <String>[];
  bool failNextWrite = false;
  bool holdFirstWrite = false;
  Completer<void>? _firstWriteGate;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('planned failure');
    }
    if (holdFirstWrite) {
      holdFirstWrite = false;
      _firstWriteGate ??= Completer<void>();
      await _firstWriteGate!.future;
    }
    writeValues.add(value);
    values[key] = value;
  }

  void releaseFirstWrite() => _firstWriteGate?.complete();
}
