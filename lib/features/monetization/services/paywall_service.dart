import 'package:fantastic_guacamole/features/monetization/domain/monetization_catalog.dart';
import 'package:fantastic_guacamole/features/monetization/domain/paywall_content.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/subscription_repository.dart';
import 'package:fantastic_guacamole/features/monetization/services/billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PaywallService {
  PaywallService(
    this._subscriptionRepository,
    this._aiCreditRepository,
    this._billingService,
  );

  final SubscriptionRepository _subscriptionRepository;
  final AiCreditRepository _aiCreditRepository;
  final BillingService _billingService;

  Future<PaywallContent> build() async {
    final SubscriptionStatus status =
        await _subscriptionRepository.getSubscriptionStatus();
    final AiCreditWallet wallet = await _aiCreditRepository.getWallet();

    final bool billingAvailable = await _billingService.isAvailable();
    final Set<String> productIds = <String>{
      for (final SubscriptionPlan plan in MonetizationCatalog.plans)
        if (plan.productId != null) plan.productId!,
      for (final AiCreditPackage pack in MonetizationCatalog.creditPackages)
        pack.productId,
    };
    final ProductDetailsResponse response =
        await _billingService.queryProductDetails(productIds);
    final Map<String, ProductDetails> detailsById = <String, ProductDetails>{
      for (final ProductDetails detail in response.productDetails) detail.id: detail,
    };

    final List<SubscriptionPlan> plans = MonetizationCatalog.plans
        .map(
          (SubscriptionPlan plan) => plan.copyWith(
            priceLabel: detailsById[plan.productId]?.price ?? plan.priceLabel,
            isAvailable:
                billingAvailable && detailsById.containsKey(plan.productId),
          ),
        )
        .toList(growable: false);

    final List<AiCreditPackage> packs = MonetizationCatalog.creditPackages
        .map(
          (AiCreditPackage pack) => pack.copyWith(
            priceLabel: detailsById[pack.productId]?.price ?? pack.priceLabel,
            isAvailable:
                billingAvailable && detailsById.containsKey(pack.productId),
          ),
        )
        .toList(growable: false);

    return PaywallContent(
      title: status.isPremium && status.isActive
          ? 'ChronoSpark Premium Active'
          : 'Unlock ChronoSpark Premium',
      body: status.isPremium && status.isActive
          ? 'Your entitlement is active. Manage your plan, review events, and top up credits.'
          : 'Upgrade for the full SI engine, premium coaching, advanced analytics, premium themes, and renewable AI credits.',
      status: status,
      wallet: wallet,
      plans: plans,
      creditPackages: packs,
      comparisonRows: MonetizationCatalog.comparisonRows,
    );
  }
}