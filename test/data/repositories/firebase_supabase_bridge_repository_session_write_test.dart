import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
    expect(source, contains('_lastSyncedAtByUserAndToken'));
    expect(source, contains('_throttleKey(expectedUserId, trimmed)'));
  });

  test(
    'same user and token remain throttled after a successful sync',
    () async {
      final _BridgeAuth auth = _BridgeAuth('bridge-throttle-a');
      final _BridgeClient client = _BridgeClient(auth);
      final FirebaseSupabaseBridgeRepository bridge = _bridge(_Backend());

      await bridge.syncFirebaseMessagingToken(client, 'same-user-token');
      await bridge.syncFirebaseMessagingToken(client, 'same-user-token');

      expect(auth.updateUserIds, <String>['bridge-throttle-a']);
    },
  );

  test(
    'A signed-out then B with the same token is not throttled by A',
    () async {
      final _BridgeAuth auth = _BridgeAuth('bridge-a');
      final _BridgeClient client = _BridgeClient(auth);
      final FirebaseSupabaseBridgeRepository bridge = _bridge(_Backend());

      await bridge.syncFirebaseMessagingToken(client, 'A-B-shared-token');
      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      auth.clearCurrentUser();
      FirebaseSupabaseBridgeRepository.resumeSessionWrites();
      auth.signIn('bridge-b');
      await bridge.syncFirebaseMessagingToken(client, 'A-B-shared-token');

      expect(auth.updateUserIds, <String>['bridge-a', 'bridge-b']);
    },
  );

  test(
    'returning A uses A throttle state rather than B throttle state',
    () async {
      final _BridgeAuth auth = _BridgeAuth('bridge-return-a');
      final _BridgeClient client = _BridgeClient(auth);
      final FirebaseSupabaseBridgeRepository bridge = _bridge(_Backend());

      await bridge.syncFirebaseMessagingToken(client, 'return-shared-token');
      auth.signIn('bridge-return-b');
      await bridge.syncFirebaseMessagingToken(client, 'return-shared-token');
      auth.signIn('bridge-return-a');
      await bridge.syncFirebaseMessagingToken(client, 'return-shared-token');

      expect(auth.updateUserIds, <String>[
        'bridge-return-a',
        'bridge-return-b',
      ]);
    },
  );

  test('a different token for the same user is not throttled', () async {
    final _BridgeAuth auth = _BridgeAuth('bridge-token-a');
    final _BridgeClient client = _BridgeClient(auth);
    final FirebaseSupabaseBridgeRepository bridge = _bridge(_Backend());

    await bridge.syncFirebaseMessagingToken(client, 'token-one');
    await bridge.syncFirebaseMessagingToken(client, 'token-two');

    expect(auth.updateUserIds, <String>['bridge-token-a', 'bridge-token-a']);
  });

  test(
    'failed attempts do not establish throttle state or affect another user',
    () async {
      final _BridgeAuth auth = _BridgeAuth('bridge-failure-a')
        ..failNextUpdate = true;
      final _BridgeClient client = _BridgeClient(auth);
      final FirebaseSupabaseBridgeRepository bridge = _bridge(_Backend());

      await bridge.syncFirebaseMessagingToken(client, 'failure-shared-token');
      await bridge.syncFirebaseMessagingToken(client, 'failure-shared-token');
      auth.signIn('bridge-failure-b');
      auth.failNextUpdate = true;
      await bridge.syncFirebaseMessagingToken(client, 'failure-shared-token');
      await bridge.syncFirebaseMessagingToken(client, 'failure-shared-token');
      auth.signIn('bridge-failure-a');
      await bridge.syncFirebaseMessagingToken(client, 'failure-shared-token');

      expect(auth.updateUserIds, <String>[
        'bridge-failure-a',
        'bridge-failure-a',
        'bridge-failure-b',
        'bridge-failure-b',
      ]);
    },
  );

  test(
    'rapid valid account sequence gives each user an initial sync',
    () async {
      final _BridgeAuth auth = _BridgeAuth('bridge-rapid-a');
      final _BridgeClient client = _BridgeClient(auth);
      final FirebaseSupabaseBridgeRepository bridge = _bridge(_Backend());

      await bridge.syncFirebaseMessagingToken(client, 'rapid-shared-token');
      auth.clearCurrentUser();
      auth.signIn('bridge-rapid-b');
      await bridge.syncFirebaseMessagingToken(client, 'rapid-shared-token');
      auth.clearCurrentUser();
      auth.signIn('bridge-rapid-c');
      await bridge.syncFirebaseMessagingToken(client, 'rapid-shared-token');

      expect(auth.updateUserIds, <String>[
        'bridge-rapid-a',
        'bridge-rapid-b',
        'bridge-rapid-c',
      ]);
    },
  );
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

class _BridgeClient extends sb.SupabaseClient {
  _BridgeClient(this.authClient)
    : super('https://example.supabase.co', 'public-anon-key');

  final _BridgeAuth authClient;

  @override
  sb.GoTrueClient get auth => authClient;
}

class _BridgeAuth extends sb.GoTrueClient {
  _BridgeAuth(String userId)
    : _currentUser = _user(userId),
      super(url: 'https://example.supabase.co');

  sb.User? _currentUser;
  final List<String> updateUserIds = <String>[];
  bool failNextUpdate = false;

  @override
  sb.User? get currentUser => _currentUser;

  @override
  Future<sb.UserResponse> updateUser(
    sb.UserAttributes attributes, {
    String? emailRedirectTo,
  }) async {
    final String userId = _currentUser!.id;
    updateUserIds.add(userId);
    if (failNextUpdate) {
      failNextUpdate = false;
      throw const sb.AuthException('planned bridge update failure');
    }
    return sb.UserResponse.fromJson(<String, dynamic>{
      'id': userId,
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  void signIn(String userId) => _currentUser = _user(userId);

  void clearCurrentUser() => _currentUser = null;
}

sb.User _user(String userId) {
  return sb.User.fromJson(<String, dynamic>{
    'id': userId,
    'aud': 'authenticated',
    'created_at': DateTime.now().toIso8601String(),
  })!;
}
