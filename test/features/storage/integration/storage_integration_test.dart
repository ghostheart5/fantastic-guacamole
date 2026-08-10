import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/sensitive_prefs_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('storage integration flow', () {
    test('shared prefs provider exposes adapter implementation', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SharedPrefsStore store = container.read(sharedPrefsStoreProvider);
      expect(store, isA<SharedPrefsStoreAdapter>());
    });

    test('sensitive prefs provider exposes singleton store', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SharedPrefsStore store = container.read(
        sensitivePrefsStoreProvider,
      );
      expect(identical(store, SensitivePrefsStore.instance), isTrue);
    });
  });
}
