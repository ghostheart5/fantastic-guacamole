import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/entitlement_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/subscription_repository.dart';

class PaywallContent {
  const PaywallContent({
    required this.subscriptionPlans,
    required this.creditPackages,
    required this.entitlement,
    required this.wallet,
  });

  final List<SubscriptionPlan> subscriptionPlans;
  final List<AiCreditPackage> creditPackages;
  final PremiumEntitlement entitlement;
  final AiCreditWallet? wallet;
}

class PaywallService {
  const PaywallService({
    required this._subscriptionRepository,
    required this._aiCreditRepository,
    required this._entitlementRepository,
  });

  final SubscriptionRepository _subscriptionRepository;
  final AiCreditRepository _aiCreditRepository;
  final EntitlementRepository _entitlementRepository;

  Future<PaywallContent> load() async {
    final List<SubscriptionPlan> plans =
        await _subscriptionRepository.getSubscriptionPlans();
    final List<AiCreditPackage> packs =
        await _aiCreditRepository.getCreditPackages();
    final PremiumEntitlement entitlement =
        await _entitlementRepository.getPremiumEntitlement();
    final AiCreditWallet? wallet = await _aiCreditRepository.getWallet();

    return PaywallContent(
      subscriptionPlans: plans,
      creditPackages: packs,
      entitlement: entitlement,
      wallet: wallet,
    );
  }
}
