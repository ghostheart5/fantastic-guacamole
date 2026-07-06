import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/repositories/si_engine_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStoreBackend backend;
  late SiEngineRepository repository;

  setUp(() {
    backend = InMemorySecureStoreBackend();
    repository = SiEngineRepository(SecureStore(backend: backend));
  });

  test('returns null when persisted SI engine state is corrupt', () async {
    await SecureStore(backend: backend).writeString('si_engine_state_v1', '{not-json');

    final Map<String, dynamic>? state = await Logger.withMutedErrors(() => repository.loadState());

    expect(state, isNull);
  });

  test('loads dynamic map state using string keys', () async {
    await repository.saveState(<String, dynamic>{'mode': 'adaptive', 'score': 7});

    final Map<String, dynamic>? state = await repository.loadState();

    expect(state, isNotNull);
    expect(state?['mode'], 'adaptive');
    expect(state?['score'], 7);
  });

  test('returns null for non-map payload types', () async {
    await SecureStore(
      backend: backend,
    ).writeString('si_engine_state_v1', jsonEncode(<String>['bad']));

    final state = await repository.loadState();

    expect(state, isNull);
  });
}
