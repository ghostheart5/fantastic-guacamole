import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class RestorePurchases {
  const RestorePurchases(this.repository);

  final IPaywallRepository repository;

  Future<SubscriptionState> call() {
    return repository.restorePurchases();
  }
}
