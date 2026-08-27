import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Subscriptions/paywall
///
/// Registered as getUserSubscriptionStateUseCaseProvider.
class GetUserSubscriptionState {
  const GetUserSubscriptionState(this.repository);

  final IPaywallRepository repository;

  Future<SubscriptionState> call() {
    return repository.getUserSubscriptionState();
  }
}
