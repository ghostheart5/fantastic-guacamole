import 'package:fantastic_guacamole/features/focus/state/focus_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FocusController', () {
    test('starts with default idle state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final FocusState state = container.read(focusControllerProvider);

      expect(state.active, isFalse);
      expect(state.seconds, 0);
      expect(state.completed, isFalse);
    });

    test('start marks active and timer ticks', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(focusControllerProvider.notifier).start();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final FocusState state = container.read(focusControllerProvider);
      expect(state.active, isTrue);
      expect(state.completed, isFalse);
      expect(state.seconds, greaterThanOrEqualTo(1));

      container.read(focusControllerProvider.notifier).complete();
    });

    test('complete stops session and marks completed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(focusControllerProvider.notifier).start();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final int beforeComplete = container.read(focusControllerProvider).seconds;

      container.read(focusControllerProvider.notifier).complete();
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final FocusState state = container.read(focusControllerProvider);
      expect(state.active, isFalse);
      expect(state.completed, isTrue);
      expect(state.seconds, beforeComplete);
    });

    test('reset returns controller to initial state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(focusControllerProvider.notifier).start();
      container.read(focusControllerProvider.notifier).reset();

      final FocusState state = container.read(focusControllerProvider);
      expect(state.active, isFalse);
      expect(state.seconds, 0);
      expect(state.completed, isFalse);
    });
  });
}
