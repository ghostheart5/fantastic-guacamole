import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Subscriptions/paywall
///
/// Resolved via paywallActionsProvider -> paywall_page. Validates planId
/// against getAvailablePlans.
/// Starts a subscription for [planId].
///
/// The plan id is validated against the repository's own available plans before
/// any purchase is attempted — an unrecognised or blank id must never reach the
/// billing layer.
class StartSubscription {
  const StartSubscription(this.repository);

  final IPaywallRepository repository;

  Future<SubscriptionState> call(String planId) async {
    InputGuard.id(planId, 'planId');

    final List<PaywallPlan> plans = await repository.getAvailablePlans();
    final bool known = plans.any((PaywallPlan plan) => plan.id == planId);
    if (!known) {
      throw ArgumentError.value(
        planId,
        'planId',
        'is not an available subscription plan',
      );
    }

    return repository.startSubscription(planId);
  }
}
