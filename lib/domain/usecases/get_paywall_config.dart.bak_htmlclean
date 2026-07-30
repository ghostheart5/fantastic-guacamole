import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class GetPaywallConfig {
  const GetPaywallConfig(this.repository);

  final IPaywallRepository repository;

  Future<PaywallEntity> call() {
    return repository.getPaywallConfig();
  }
}
