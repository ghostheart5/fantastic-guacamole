import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/policies/input_guard.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Subscriptions/paywall
///
/// Registered as checkEntitlementUseCaseProvider; access checks currently run
/// through appAccessProvider.
/// Checks whether the user is entitled to [featureId].
///
/// [featureId] is required and must be non-blank: a null/blank id previously
/// went straight to the repository, leaving "which feature?" ambiguous at the
/// exact point where paid access is granted.
class CheckEntitlement {
  const CheckEntitlement(this.repository);

  final IPaywallRepository repository;

  Future<Entitlement> call({required String featureId}) {
    return repository.checkEntitlement(
      featureId: InputGuard.id(featureId, 'featureId'),
    );
  }
}
