import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class PaywallService {
  PaywallService(this._repository);

  final IPaywallRepository _repository;

  Future<List<PaywallPlan>> getAvailablePlans() {
    return _repository.getAvailablePlans();
  }

  Future<PaywallEntity> getPaywallConfig() {
    return _repository.getPaywallConfig();
  }

  Future<Entitlement> checkEntitlement({String? featureId}) {
    return _repository.checkEntitlement(featureId: featureId);
  }

  Future<SubscriptionState> startSubscription(String planId) {
    return _repository.startSubscription(planId);
  }

  Future<SubscriptionState> cancelSubscription() {
    return _repository.cancelSubscription();
  }

  Future<SubscriptionState> restorePurchases() {
    return _repository.restorePurchases();
  }

  Future<SubscriptionState> getUserSubscriptionState() {
    return _repository.getUserSubscriptionState();
  }
}
