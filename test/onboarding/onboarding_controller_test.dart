import 'package:fantastic_guacamole/onboarding/controllers/onboarding_controller.dart';
import 'package:fantastic_guacamole/onboarding/state/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final NotifierProvider<OnboardingController, OnboardingState> provider =
      NotifierProvider<OnboardingController, OnboardingState>(
        OnboardingController.new,
      );

  test('starts in initial state and start moves to step zero', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(provider), isA<OnboardingInitial>());

    container.read(provider.notifier).start();
    final OnboardingState started = container.read(provider);
    expect(started, isA<OnboardingInProgress>());
    final OnboardingInProgress progress = started as OnboardingInProgress;
    expect(progress.step, 0);
    expect(progress.totalSteps, 4);
  });

  test('nextStep advances and completes at final step', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final OnboardingController controller = container.read(provider.notifier);
    controller.start();

    controller.nextStep();
    expect((container.read(provider) as OnboardingInProgress).step, 1);

    controller.nextStep();
    expect((container.read(provider) as OnboardingInProgress).step, 2);

    controller.nextStep();
    expect((container.read(provider) as OnboardingInProgress).step, 3);

    controller.nextStep();
    expect(container.read(provider), isA<OnboardingComplete>());
  });

  test('previousStep does not underflow below zero', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final OnboardingController controller = container.read(provider.notifier);
    controller.start();

    controller.previousStep();
    final OnboardingInProgress state =
        container.read(provider) as OnboardingInProgress;
    expect(state.step, 0);
  });

  test('reset returns to initial state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final OnboardingController controller = container.read(provider.notifier);
    controller.start();
    controller.nextStep();

    controller.reset();
    expect(container.read(provider), isA<OnboardingInitial>());
  });
}
