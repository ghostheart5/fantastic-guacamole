import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';

/// Account-bound transaction feedback; never subscription access authority.
class PurchaseOutcome {
  const PurchaseOutcome(this.userId, this.state);
  final String? userId;
  final SubscriptionState state;
}

abstract interface class IPurchaseOutcomeSource {
  Stream<PurchaseOutcome> get purchaseOutcomes;
}
