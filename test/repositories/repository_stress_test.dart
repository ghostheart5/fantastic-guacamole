import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repository stress tests', () {
    test('repository providers survive repeated access', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 100; i++) {
        expect(() => container.read(taskRepositoryProvider), returnsNormally);
        expect(() => container.read(goalRepositoryProvider), returnsNormally);
        expect(() => container.read(flowmapRepositoryProvider), returnsNormally);
        expect(() => container.read(planRepositoryProvider), returnsNormally);
        expect(
          () => container.read(progressionRepositoryProvider),
          returnsNormally,
        );
      }
    });

    test('repository instances remain available together', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(taskRepositoryProvider), isNotNull);
      expect(container.read(goalRepositoryProvider), isNotNull);
      expect(container.read(flowmapRepositoryProvider), isNotNull);
      expect(container.read(planRepositoryProvider), isNotNull);
      expect(container.read(progressionRepositoryProvider), isNotNull);
    });

    test('repository initialization order does not matter', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(flowmapRepositoryProvider);
      container.read(taskRepositoryProvider);
      container.read(progressionRepositoryProvider);
      container.read(goalRepositoryProvider);
      container.read(planRepositoryProvider);

      expect(true, isTrue);
    });
  });
}
