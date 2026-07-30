import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class StartSubscription {
  const StartSubscription(this.repository);

  final IPaywallRepository repository;

  Future<SubscriptionState> call(String planId) {
    return repository.startSubscription(planId);
  }
}
