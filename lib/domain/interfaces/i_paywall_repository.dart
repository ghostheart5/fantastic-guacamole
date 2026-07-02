import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';

abstract class IPaywallRepository {
  Future<List<PaywallPlan>> getAvailablePlans();
  Future<PaywallEntity> getPaywallConfig();
  Future<Entitlement> checkEntitlement({String? featureId});
  Future<SubscriptionState> startSubscription(String planId);
  Future<SubscriptionState> cancelSubscription();
  Future<SubscriptionState> restorePurchases();
  Future<SubscriptionState> getUserSubscriptionState();
}
