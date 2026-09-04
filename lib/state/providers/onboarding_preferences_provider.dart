import 'package:fantastic_guacamole/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_onboarding_preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final onboardingPreferencesRepositoryProvider =
    Provider<IOnboardingPreferencesRepository>((Ref ref) {
      return SharedPreferencesOnboardingRepository();
    });
