import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class CheckEntitlement {
  const CheckEntitlement(this.repository);

  final IPaywallRepository repository;

  Future<Entitlement> call({String? featureId}) {
    return repository.checkEntitlement(featureId: featureId);
  }
}
