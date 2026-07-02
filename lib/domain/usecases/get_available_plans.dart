import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';

class GetAvailablePlans {
  const GetAvailablePlans(this.repository);

  final IPaywallRepository repository;

  Future<List<PaywallPlan>> call() {
    return repository.getAvailablePlans();
  }
}
