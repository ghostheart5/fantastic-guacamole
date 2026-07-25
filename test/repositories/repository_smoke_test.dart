import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repository smoke tests', () {
    test('core local repositories initialize without throwing', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(() => container.read(taskRepositoryProvider), returnsNormally);
      expect(() => container.read(goalRepositoryProvider), returnsNormally);
      expect(() => container.read(timelineRepositoryProvider), returnsNormally);
      expect(() => container.read(memoryRepositoryProvider), returnsNormally);
      expect(() => container.read(logRepositoryProvider), returnsNormally);
      expect(() => container.read(flowmapRepositoryProvider), returnsNormally);
      expect(() => container.read(progressionRepositoryProvider), returnsNormally);
      expect(() => container.read(planRepositoryProvider), returnsNormally);
      expect(() => container.read(notificationsRepositoryProvider), returnsNormally);
      expect(() => container.read(profileRepositoryProvider), returnsNormally);
    });

    test('repository providers can be read repeatedly', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 25; i++) {
        container.read(taskRepositoryProvider);
        container.read(goalRepositoryProvider);
        container.read(timelineRepositoryProvider);
        container.read(memoryRepositoryProvider);
        container.read(logRepositoryProvider);
        container.read(flowmapRepositoryProvider);
      }
    });

    test('repository provider instances are available in same container', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final taskRepository = container.read(taskRepositoryProvider);
      final goalRepository = container.read(goalRepositoryProvider);
      final timelineRepository = container.read(timelineRepositoryProvider);
      final memoryRepository = container.read(memoryRepositoryProvider);

      expect(taskRepository, isNotNull);
      expect(goalRepository, isNotNull);
      expect(timelineRepository, isNotNull);
      expect(memoryRepository, isNotNull);
    });
  });
}
