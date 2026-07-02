import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/features/paywall/services/paywall_service.dart';

class BillingService {
  BillingService(this._paywallService);

  final PaywallService _paywallService;

  Future<SubscriptionState> purchase(String planId) {
    return _paywallService.startSubscription(planId);
  }

  Future<SubscriptionState> restore() {
    return _paywallService.restorePurchases();
  }

  Future<SubscriptionState> cancel() {
    return _paywallService.cancelSubscription();
  }
}
