import 'package:fantastic_guacamole/domain/entities/entitlement.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Subscriptions/paywall
///
/// Supertype of IPaywallRepository; bound through it.
abstract class IEntitlementRepository {
  Future<Entitlement> checkEntitlement({String? featureId});
}
