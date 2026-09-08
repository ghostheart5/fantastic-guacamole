import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_entitlement_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';

class PurchaseOutcome {
  const PurchaseOutcome(this.userId, this.state);
  final String? userId;
  final SubscriptionState state;
}

/// Transaction feedback is separate from subscription access authority.
abstract interface class IPurchaseOutcomeSource {
  Stream<PurchaseOutcome> get purchaseOutcomes;
}

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Subscriptions/paywall
///
/// Bound to PaywallRepository or GooglePlayPaywallRepository by platform.
abstract class IPaywallRepository
    implements ISubscriptionRepository, IEntitlementRepository {
  @override
  Future<List<PaywallPlan>> getAvailablePlans();

  @override
  Future<PaywallEntity> getPaywallConfig();

  @override
  Future<Entitlement> checkEntitlement({String? featureId});

  @override
  Future<SubscriptionState> startSubscription(String planId);

  @override
  Future<SubscriptionState> cancelSubscription();

  @override
  Future<SubscriptionState> restorePurchases();

  @override
  Future<SubscriptionState> getUserSubscriptionState();
}
