import 'package:fantastic_guacamole/onboarding/state/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingController extends Notifier<OnboardingState> {
  static const int _totalSteps = 4;

  @override
  OnboardingState build() => const OnboardingInitial();

  void start() {
    state = const OnboardingInProgress(step: 0, totalSteps: _totalSteps);
  }

  void nextStep() {
    if (state is! OnboardingInProgress) return;
    final current = state as OnboardingInProgress;
    if (current.step + 1 >= current.totalSteps) {
      complete();
    } else {
      state = OnboardingInProgress(
        step: current.step + 1,
        totalSteps: current.totalSteps,
      );
    }
  }

  void previousStep() {
    if (state is! OnboardingInProgress) return;
    final current = state as OnboardingInProgress;
    if (current.step > 0) {
      state = OnboardingInProgress(
        step: current.step - 1,
        totalSteps: current.totalSteps,
      );
    }
  }

  void complete() {
    state = const OnboardingComplete();
  }

  void reset() {
    state = const OnboardingInitial();
  }
}
