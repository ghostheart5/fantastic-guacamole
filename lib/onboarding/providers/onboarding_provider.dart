import 'package:fantastic_guacamole/onboarding/controllers/onboarding_controller.dart';
import 'package:fantastic_guacamole/onboarding/state/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
