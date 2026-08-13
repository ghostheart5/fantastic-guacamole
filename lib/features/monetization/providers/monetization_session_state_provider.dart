import 'package:fantastic_guacamole/features/monetization/presentation/controllers/credit_store_controller.dart';
import 'package:fantastic_guacamole/features/monetization/presentation/controllers/paywall_controller.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clears all account-owned monetization state after an auth identity change.
void invalidateMonetizationSessionState(Ref ref) {
  refreshMonetizationRemoteState(ref);
  ref.invalidate(paywallControllerProvider);
  ref.invalidate(creditStoreControllerProvider);
  ref.invalidate(paywallPromptProvider);
}
