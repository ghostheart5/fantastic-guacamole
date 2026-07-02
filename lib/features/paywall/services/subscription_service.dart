import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/features/paywall/services/paywall_service.dart';

class SubscriptionService {
  SubscriptionService(this._paywallService);

  final PaywallService _paywallService;

  Future<SubscriptionState> current() {
    return _paywallService.getUserSubscriptionState();
  }

  Future<bool> isPremiumActive() async {
    return (await current()).isActive;
  }
}
