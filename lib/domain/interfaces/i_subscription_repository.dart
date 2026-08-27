import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Subscriptions/paywall
///
/// Supertype of IPaywallRepository; bound through it.
abstract class ISubscriptionRepository {
  Future<List<PaywallPlan>> getAvailablePlans();
  Future<PaywallEntity> getPaywallConfig();
  Future<SubscriptionState> startSubscription(String planId);
  Future<SubscriptionState> cancelSubscription();
  Future<SubscriptionState> restorePurchases();
  Future<SubscriptionState> getUserSubscriptionState();
}
