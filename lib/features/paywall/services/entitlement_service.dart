import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/features/paywall/services/paywall_service.dart';

class EntitlementService {
  EntitlementService(this._paywallService);

  final PaywallService _paywallService;

  Future<Entitlement> check({String? featureId}) {
    return _paywallService.checkEntitlement(featureId: featureId);
  }

  Future<bool> hasAccess({String? featureId}) async {
    return (await check(featureId: featureId)).isEntitled;
  }
}
