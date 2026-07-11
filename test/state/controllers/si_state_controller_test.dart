import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? _) async {
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('build starts with default SI state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(siStateProvider), const SIState());
  });

  test('sessionComplete updates energy fatigue and completion count', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(siStateProvider.notifier).reset();
    container.read(siStateProvider.notifier).sessionComplete();

    final state = container.read(siStateProvider);
    expect(state.completedToday, 1);
    expect(state.energy, closeTo(0.62, 0.0001));
    expect(state.fatigue, closeTo(0.4, 0.0001));
  });

  test('adjustEnergy and adjustFatigue clamp between 0 and 1', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(siStateProvider.notifier)
        .replaceState(energy: 0.9, fatigue: 0.1);
    container.read(siStateProvider.notifier).adjustEnergy(0.5);
    container.read(siStateProvider.notifier).adjustFatigue(-0.5);

    final state = container.read(siStateProvider);
    expect(state.energy, 1.0);
    expect(state.fatigue, 0.0);
  });

  test('replaceState and reset behave predictably', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(siStateProvider.notifier)
        .replaceState(energy: 0.2, fatigue: 0.9, completedToday: 4);
    expect(container.read(siStateProvider).completedToday, 4);

    container.read(siStateProvider.notifier).reset();
    expect(container.read(siStateProvider), const SIState());
  });
}
