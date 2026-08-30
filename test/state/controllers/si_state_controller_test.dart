import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build starts with default SI state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(siStateProvider), const SIState());
  });

  test('recordCompletion does not invent energy or fatigue', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(siStateProvider.notifier).reset();
    container.read(siStateProvider.notifier).recordCompletion();

    final state = container.read(siStateProvider);
    expect(state.completedToday, 1);
    expect(state.energy, 0.5);
    expect(state.fatigue, 0.5);
    expect(state.hasObservedEnergy, isFalse);
    expect(state.hasObservedFatigue, isFalse);
  });

  test('explicit adjustments clamp and become observed reports', () {
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
    expect(state.energyOrigin, PredictiveEvidenceOrigin.observed);
    expect(state.fatigueOrigin, PredictiveEvidenceOrigin.observed);
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

  test('task evidence never changes unavailable human state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(siStateProvider.notifier).recordCompletion();
    container.read(siStateProvider.notifier).taskSkipped();

    final SIState state = container.read(siStateProvider);
    expect(state.energy, 0.5);
    expect(state.fatigue, 0.5);
    expect(state.completedToday, 1);
    expect(state.energyOrigin, PredictiveEvidenceOrigin.unavailable);
    expect(state.fatigueOrigin, PredictiveEvidenceOrigin.unavailable);
  });
}
