import 'package:flutter/foundation.dart';

@immutable
abstract class OnboardingState {
  const OnboardingState();
}

class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

class OnboardingInProgress extends OnboardingState {
  const OnboardingInProgress({required this.step, required this.totalSteps});
  final int step;
  final int totalSteps;
}

class OnboardingComplete extends OnboardingState {
  const OnboardingComplete();
}
