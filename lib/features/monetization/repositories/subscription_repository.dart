import 'package:fantastic_guacamole/features/monetization/data/monetization_remote_data_source.dart';
import 'package:fantastic_guacamole/features/monetization/models/entitlement_event.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';

abstract class SubscriptionRepository {
  Future<SubscriptionStatus> getSubscriptionStatus();
  Future<List<EntitlementEvent>> getEntitlementEvents();
}

class SupabaseSubscriptionRepository implements SubscriptionRepository {
  SupabaseSubscriptionRepository(this._dataSource);

  final MonetizationRemoteDataSource _dataSource;

  @override
  Future<List<EntitlementEvent>> getEntitlementEvents() {
    return _dataSource.fetchEntitlementEvents();
  }

  @override
  Future<SubscriptionStatus> getSubscriptionStatus() {
    return _dataSource.fetchSubscriptionStatus();
  }
}