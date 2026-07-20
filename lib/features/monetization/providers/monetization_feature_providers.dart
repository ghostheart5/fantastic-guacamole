import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/entitlement_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/subscription_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/ai_credit_service.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/paywall_service.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/premium_access_service.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/purchase_verification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

final _httpClientProvider = Provider<http.Client>((Ref ref) {
  return http.Client();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((Ref ref) {
  return SupabaseSubscriptionRepository(ref.watch(supabaseClientProvider));
});

final aiCreditRepositoryProvider = Provider<AiCreditRepository>((Ref ref) {
  return SupabaseAiCreditRepository(ref.watch(supabaseClientProvider));
});

final entitlementRepositoryProvider = Provider<EntitlementRepository>((Ref ref) {
  return SupabaseEntitlementRepository(ref.watch(supabaseClientProvider));
});

final purchaseVerificationServiceProvider = Provider<PurchaseVerificationService>((Ref ref) {
  return PurchaseVerificationService(
    httpClient: ref.watch(_httpClientProvider),
    mode: resolvePurchaseVerificationMode(),
  );
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((Ref ref) {
  return GooglePlayPurchaseRepository(
    InAppPurchase.instance,
    ref.watch(purchaseVerificationServiceProvider),
  );
});

final premiumAccessServiceProvider = Provider<PremiumAccessService>((Ref ref) {
  return PremiumAccessService(ref.watch(entitlementRepositoryProvider));
});

final aiCreditServiceProvider = Provider<AiCreditService>((Ref ref) {
  return AiCreditService(ref.watch(aiCreditRepositoryProvider));
});

final paywallServiceProvider = Provider<PaywallService>((Ref ref) {
  return PaywallService(
    subscriptionRepository: ref.watch(subscriptionRepositoryProvider),
    aiCreditRepository: ref.watch(aiCreditRepositoryProvider),
    entitlementRepository: ref.watch(entitlementRepositoryProvider),
  );
});

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((Ref ref) {
  return ref.watch(subscriptionRepositoryProvider).getSubscriptionPlans();
});

final currentSubscriptionProvider = FutureProvider<UserSubscription?>((Ref ref) {
  return ref.watch(subscriptionRepositoryProvider).getCurrentSubscription();
});

final premiumEntitlementProvider = FutureProvider<PremiumEntitlement>((Ref ref) {
  return ref.watch(entitlementRepositoryProvider).getPremiumEntitlement();
});

final entitlementTierProvider = Provider<EntitlementTier>((Ref ref) {
  return ref.watch(premiumEntitlementProvider).maybeWhen(
        data: (PremiumEntitlement entitlement) => entitlement.tier,
        orElse: () => EntitlementTier.free,
      );
});

final hasPremiumTierAccessProvider = Provider<bool>((Ref ref) {
  final EntitlementTier tier = ref.watch(entitlementTierProvider);
  return tier == EntitlementTier.premium || tier == EntitlementTier.ultimate;
});

final hasUltimateTierAccessProvider = Provider<bool>((Ref ref) {
  return ref.watch(entitlementTierProvider) == EntitlementTier.ultimate;
});

final aiCreditPackagesProvider = FutureProvider<List<AiCreditPackage>>((Ref ref) {
  return ref.watch(aiCreditRepositoryProvider).getCreditPackages();
});

final aiCreditWalletProvider = FutureProvider<AiCreditWallet?>((Ref ref) {
  return ref.watch(aiCreditRepositoryProvider).getWallet();
});

final aiCreditTransactionsProvider = FutureProvider<List<AiCreditTransaction>>((Ref ref) {
  return ref.watch(aiCreditRepositoryProvider).getTransactions();
});

final purchaseHistoryProvider = FutureProvider<List<AiCreditPurchase>>((Ref ref) {
  return ref.watch(aiCreditRepositoryProvider).getPurchaseHistory();
});

final premiumAccessProvider = Provider<bool>((Ref ref) {
  return ref.watch(hasPremiumTierAccessProvider);
});
