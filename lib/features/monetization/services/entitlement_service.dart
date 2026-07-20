import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/subscription_repository.dart';

class EntitlementService {
  const EntitlementService(this._repository);

  final SubscriptionRepository _repository;

  Future<SubscriptionStatus> refreshEntitlements() {
    return _repository.getSubscriptionStatus();
  }

  Future<List<EntitlementEvent>> loadEvents() {
    return _repository.getEntitlementEvents();
  }

  Future<bool> hasPremiumAccess() async {
    final SubscriptionStatus status = await refreshEntitlements();
    return status.isPremium && status.isActive;
  }
}