import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/neural_history_store.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final neuralHistoryStoreProvider = Provider<NeuralHistoryStore>((ref) {
  return NeuralHistoryStore(
    scope: ref.watch(accountStorageScopeProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});
