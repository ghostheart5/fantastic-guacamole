import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Subscriptions/paywall
///
/// Registered as cancelSubscriptionUseCaseProvider; no in-app cancel flow yet.
class CancelSubscription {
  const CancelSubscription(this.repository);

  final IPaywallRepository repository;

  Future<SubscriptionState> call() {
    return repository.cancelSubscription();
  }
}
