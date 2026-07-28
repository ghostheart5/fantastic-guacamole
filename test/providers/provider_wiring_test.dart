import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('provider wiring', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('critical providers can be read from a container', () {
      expect(container.read(secureStoreProvider), isNotNull);
      expect(container.read(hiveStoreProvider), isNotNull);
      expect(container.read(sharedPrefsStoreProvider), isNotNull);
      expect(container.read(taskRepositoryProvider), isNotNull);
      expect(container.read(profileRepositoryProvider), isNotNull);
      expect(container.read(authRepositoryProvider), isNotNull);
      expect(container.read(authServiceProvider), isNotNull);
    });
  });
}
