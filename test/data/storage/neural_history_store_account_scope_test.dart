import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/neural_history_store.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/controllable_secure_store_backend.dart';

void main() {
  late ControllableSecureStoreBackend backend;
  late SecureStore secureStore;

  setUp(() {
    backend = ControllableSecureStoreBackend();
    secureStore = SecureStore(backend: backend);
  });

  test('neural history is isolated A to B to A with same task title', () async {
    final a = _store('A', secureStore);
    final b = _store('B', secureStore);
    await a.appendNeuralEntry(_entry('shared-task', 'A_SECRET_NEURAL_ENTRY'));
    expect((await a.loadNeuralHistory()).single.reasoning, 'A_SECRET_NEURAL_ENTRY');
    expect(await b.loadNeuralHistory(), isEmpty);
    await b.appendNeuralEntry(_entry('shared-task', 'B_SECRET_NEURAL_ENTRY'));
    expect((await a.loadNeuralHistory()).single.reasoning, 'A_SECRET_NEURAL_ENTRY');
    expect((await b.loadNeuralHistory()).single.reasoning, 'B_SECRET_NEURAL_ENTRY');
    expect(a.storageKey, isNot(b.storageKey));
  });

  test('legacy remains inert and signed-out fails closed', () async {
    backend.values[NeuralHistoryStore.legacyStorageKey] = 'LEGACY_PRIVATE_NEURAL_HISTORY';
    final a = _store('A', secureStore);
    await a.appendNeuralEntry(_entry('A_TASK', 'A_SECRET_NEURAL_ENTRY'));
    final signedOut = NeuralHistoryStore(
      scope: const AccountStorageScope.signedOut(),
      secureStore: secureStore,
    );
    expect(await signedOut.loadNeuralHistory(), isEmpty);
    await signedOut.appendNeuralEntry(_entry('ignored', 'SIGNED_OUT_SECRET'));
    expect(signedOut.storageKey, isNull);
    expect(backend.values[NeuralHistoryStore.legacyStorageKey], 'LEGACY_PRIVATE_NEURAL_HISTORY');
    expect(backend.values.keys, isNot(contains('neural_dump_v2.signed_out')));
  });

  test('fresh stores restore only their authenticated V2 history', () async {
    final a = _store('A', secureStore);
    final b = _store('B', secureStore);
    await a.appendNeuralEntry(_entry('A_TASK', 'A_RESTART'));
    await b.appendNeuralEntry(_entry('B_TASK', 'B_RESTART'));
    expect((await _store('A', secureStore).loadNeuralHistory()).single.reasoning, 'A_RESTART');
    expect((await _store('B', secureStore).loadNeuralHistory()).single.reasoning, 'B_RESTART');
    expect(
      await NeuralHistoryStore(scope: const AccountStorageScope.signedOut(), secureStore: secureStore).loadNeuralHistory(),
      isEmpty,
    );
  });

  test('a delayed A load remains bound to A V2 key after B is available', () async {
    final a = _store('A', secureStore);
    final b = _store('B', secureStore);
    await a.appendNeuralEntry(_entry('A_TASK', 'A_DELAYED'));
    await b.appendNeuralEntry(_entry('B_TASK', 'B_CURRENT'));
    backend.holdNextReadFor(a.storageKey!);
    final aLoad = a.loadNeuralHistory();
    await backend.waitUntilReadStarted(a.storageKey!);
    expect((await b.loadNeuralHistory()).single.reasoning, 'B_CURRENT');
    backend.releaseHeldRead();
    expect((await aLoad).single.reasoning, 'A_DELAYED');
    expect(backend.reads, containsAll(<String>[a.storageKey!, b.storageKey!]));
  });

  test('scoped write failure preserves history and retry stays account local',
      () async {
    final a = _store('A', secureStore);
    final b = _store('B', secureStore);
    final String aKey = a.storageKey!;
    await a.appendNeuralEntry(_entry('shared-task', 'A_EXISTING'));
    backend.failingWrites.add(aKey);

    await expectLater(
      a.appendNeuralEntry(_entry('shared-task', 'A_FAILED')),
      throwsA(isA<StateError>()),
    );
    expect((await a.loadNeuralHistory()).single.reasoning, 'A_EXISTING');
    expect(await b.loadNeuralHistory(), isEmpty);

    backend.failingWrites.remove(aKey);
    await a.appendNeuralEntry(_entry('shared-task', 'A_RETRY'));
    expect(
      (await a.loadNeuralHistory()).map((NeuralEntry e) => e.reasoning),
      <String>['A_EXISTING', 'A_RETRY'],
    );
    expect(await b.loadNeuralHistory(), isEmpty);
  });
}

NeuralHistoryStore _store(String user, SecureStore secureStore) => NeuralHistoryStore(
  scope: AccountStorageScope.authenticated(user),
  secureStore: secureStore,
);

NeuralEntry _entry(String task, String reasoning) => NeuralEntry(
  task: task,
  reasoning: reasoning,
  confidence: .8,
  duration: 60,
  quality: .9,
  timestamp: DateTime.utc(2026),
);
