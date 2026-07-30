import 'package:fantastic_guacamole/features/monetization/data/models/premium_entitlement.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/entitlement_repository.dart';

class PremiumAccessService {
  const PremiumAccessService(this._entitlementRepository);

  final EntitlementRepository _entitlementRepository;

  Future<PremiumEntitlement> getEntitlement() {
    return _entitlementRepository.getPremiumEntitlement();
  }

  Future<bool> hasPremiumAccess() async {
    final PremiumEntitlement entitlement = await getEntitlement();
    return entitlement.isPremium && entitlement.isActive;
  }
}
