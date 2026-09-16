import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/launch_containment.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart'
    show appPaywallRepositoryProvider;
import 'package:fantastic_guacamole/state/providers/storage_providers.dart'
    show sharedPrefsStoreProvider, supabaseClientProvider;
import 'package:fantastic_guacamole/data/storage/account_scoped_shared_prefs_store.dart';
import 'package:fantastic_guacamole/data/repositories/paywall_repository.dart'
    show ContainedPaywallRepository;
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/purchase_outcome.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/cancel_subscription.dart';
import 'package:fantastic_guacamole/domain/usecases/check_entitlement.dart';
import 'package:fantastic_guacamole/domain/usecases/get_available_plans.dart';
import 'package:fantastic_guacamole/domain/usecases/get_paywall_config.dart';
import 'package:fantastic_guacamole/domain/usecases/get_user_subscription_state.dart';
import 'package:fantastic_guacamole/domain/usecases/restore_purchases.dart';
import 'package:fantastic_guacamole/domain/usecases/start_subscription.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService(
    spendingEnabled:
        ref.watch(creditSpendingAvailableProvider) && !Env.isProduction,
    prefs: AccountScopedSharedPrefsStore(
      delegate: ref.read(sharedPrefsStoreProvider),
      scope: ref.watch(accountStorageScopeProvider),
      legacyOwnership: ref.watch(accountLegacyOwnershipProvider),
    ),
  );
});

final aiCreditWalletProvider = FutureProvider<AiCreditWallet>((ref) async {
  if (!ref.watch(creditSpendingAvailableProvider)) {
    final DateTime now = DateTime.now();
    return AiCreditWallet(
      balance: 0,
      tier: 'unavailable',
      allowance: 0,
      resetAt: now,
      updatedAt: now,
    );
  }
  final bool testerAccess = ref.watch(appAccessProvider).hasTesterFullAccess;
  // Wait for entitlement to resolve before touching the wallet. Loading it
  // while access is still unknown would rebuild a premium wallet as free and
  // reset the user's balance on every launch.
  final EntitlementState entitlement = await ref.watch(
    entitlementProvider.future,
  );
  final bool premium = testerAccess || entitlement.isPremium;
  if (Env.isProduction && ref.watch(aiProxyAvailableProvider)) {
    final client = ref.watch(supabaseClientProvider);
    if (client?.auth.currentUser == null) {
      throw StateError('An authenticated session is required for AI credits.');
    }
    final row = Map<String, dynamic>.from(
      await client!.rpc<Map<String, dynamic>>('get_credit_wallet_v2'),
    );
    return serverAiCreditWallet(row);
  }
  return ref.read(creditServiceProvider).loadWallet(premium: premium);
});

AiCreditWallet serverAiCreditWallet(Map<String, dynamic> row) {
  final DateTime now = DateTime.now();
  return AiCreditWallet(
    purchasedCredits: ((row['purchased_credits'] as num?)?.toInt() ?? 0)
        .clamp(0, 1 << 31)
        .toInt(),
    refundedCreditDebt: ((row['refunded_credit_debt'] as num?)?.toInt() ?? 0)
        .clamp(0, 1 << 31)
        .toInt(),
    balance: ((row['balance'] as num?)?.toInt() ?? 0).clamp(0, 1 << 31).toInt(),
    tier:
        const {
          'premium',
          'premium_monthly',
          'premium_yearly',
        }.contains(row['tier'])
        ? 'premium'
        : 'free',
    allowance: ((row['period_credits'] as num?)?.toInt() ?? 0)
        .clamp(0, 1 << 31)
        .toInt(),
    resetAt:
        DateTime.tryParse(row['period_ends_at']?.toString() ?? '')?.toLocal() ??
        now,
    updatedAt:
        DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal() ??
        now,
  );
}

final paywallRepositoryProvider = Provider<IPaywallRepository>((ref) {
  return ref.watch(appPaywallRepositoryProvider);
});

final paywallPurchaseOutcomeProvider =
    StreamProvider.autoDispose<SubscriptionState>((ref) {
      ref.watch(accountStorageScopeProvider);
      final repository = ref.watch(paywallRepositoryProvider);
      if (repository is! IPurchaseOutcomeSource) return const Stream.empty();
      return (repository as IPurchaseOutcomeSource).purchaseOutcomes
          .where(
            (event) =>
                event.userId ==
                ref.read(supabaseClientProvider)?.auth.currentUser?.id,
          )
          .map((event) => event.state);
    });

final getAvailablePlansUseCaseProvider = Provider<GetAvailablePlans>((ref) {
  return GetAvailablePlans(ref.watch(paywallRepositoryProvider));
});

final startSubscriptionUseCaseProvider = Provider<StartSubscription>((ref) {
  return StartSubscription(ref.watch(paywallRepositoryProvider));
});

final restorePurchasesUseCaseProvider = Provider<RestorePurchases>((ref) {
  return RestorePurchases(ref.watch(paywallRepositoryProvider));
});

final cancelSubscriptionUseCaseProvider = Provider<CancelSubscription>((ref) {
  return CancelSubscription(ref.watch(paywallRepositoryProvider));
});

final getPaywallConfigUseCaseProvider = Provider<GetPaywallConfig>((ref) {
  return GetPaywallConfig(ref.watch(paywallRepositoryProvider));
});

final getUserSubscriptionStateUseCaseProvider =
    Provider<GetUserSubscriptionState>((ref) {
      return GetUserSubscriptionState(ref.watch(paywallRepositoryProvider));
    });

final checkEntitlementUseCaseProvider = Provider<CheckEntitlement>((ref) {
  return CheckEntitlement(ref.watch(paywallRepositoryProvider));
});

final paywallActionsProvider = Provider<PaywallActions>((ref) {
  return PaywallActions(ref);
});

final paywallSubscriptionProvider = FutureProvider<SubscriptionState>((
  ref,
) async {
  final subscription = await ref
      .watch(paywallRepositoryProvider)
      .getUserSubscriptionState();
  if (!ref.mounted) return subscription;
  final expiry = subscription.renewalDate;
  if (subscription.isActive && expiry != null) {
    final remaining = expiry.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return SubscriptionState(
        isActive: false,
        status: 'expired',
        source: subscription.source,
        planId: subscription.planId,
        renewalDate: expiry,
        isTesting: subscription.isTesting,
      );
    }
    final timer = Timer(remaining, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return subscription;
});

final paywallConfigProvider = FutureProvider<PaywallEntity>((ref) async {
  if (!ref.watch(subscriptionPurchasingEnabledProvider)) {
    return const ContainedPaywallRepository().getPaywallConfig();
  }
  final bool billingTest = ref.watch(internalBillingTestEnabledProvider);
  final plansUseCase = ref.watch(getAvailablePlansUseCaseProvider);
  final subscriptionFuture = ref.watch(paywallSubscriptionProvider.future);
  final List<PaywallPlan> plans = await plansUseCase.call();
  final SubscriptionState subscription = await subscriptionFuture;
  if (billingTest) {
    final creditsEnabled = ref.watch(internalCreditTestEnabledProvider);
    return PaywallEntity(
      featureId: 'premium',
      title: 'Google Play billing test',
      body:
          'Test purchases, renewals, cancellation and restoration. Select a Google Play test payment method; cancel if a real payment method appears. '
          '${creditsEnabled ? 'Settings includes synthetic credit-test actions that require external AI consent and use server-verified credits. SI Console guidance remains local.' : 'AI and credit spending are unavailable in this build.'}',
      plans: plans
          .map(
            (plan) => PaywallPlan(
              id: plan.id,
              title: plan.title,
              priceLabel: plan.priceLabel,
              description: plan.description,
              aiCreditsIncluded: creditsEnabled ? plan.aiCreditsIncluded : 0,
              isAvailable: plan.isAvailable,
              isFeatured: plan.isFeatured,
            ),
          )
          .toList(growable: false),
      isUnlocked: subscription.isActive,
    );
  }
  return PaywallEntity(
    featureId: 'premium',
    title: subscription.isTesting
        ? 'Unlocked for testing'
        : 'External-assistant credit plans',
    body: subscription.isTesting
        ? 'Subscription checks are bypassed in this testing mode.'
        : 'Choose a plan. Google Play provides the displayed price and confirms billing frequency and renewal terms before purchase. Credits are granted only after a verified purchase or paid renewal.',
    plans: plans,
    isUnlocked: subscription.isActive,
  );
});

class PaywallActions {
  const PaywallActions(this._ref);

  final Ref _ref;

  Future<SubscriptionState> startSubscription(String planId) async {
    if (!_ref.read(subscriptionPurchasingEnabledProvider)) {
      throw const LaunchContainedException('Subscriptions');
    }
    final SubscriptionState purchased = await _ref
        .read(startSubscriptionUseCaseProvider)
        .call(planId);
    // A subscription read cannot confirm or reject a one-time credit purchase.
    // Preserve its transaction outcome; the page refreshes wallet and access
    // independently after this operation.
    if (planId.startsWith('credits_')) return purchased;
    return _refreshAuthority(purchased);
  }

  Future<SubscriptionState> restorePurchases() async {
    if (!_ref.read(subscriptionPurchasingEnabledProvider)) {
      throw const LaunchContainedException('Purchase restoration');
    }
    final SubscriptionState restored = await _ref
        .read(restorePurchasesUseCaseProvider)
        .call();
    return _refreshAuthority(restored);
  }

  Future<SubscriptionState> _refreshAuthority(
    SubscriptionState fallback,
  ) async {
    if (!requiresPaywallAuthorityRefresh(fallback)) {
      return fallback;
    }
    final repository = _ref.read(paywallRepositoryProvider);
    final ISubscriptionAuthorityRefresher? authorityRefresher =
        repository is ISubscriptionAuthorityRefresher
        ? repository as ISubscriptionAuthorityRefresher
        : null;
    if (authorityRefresher != null) {
      return authorityRefresher.refreshSubscriptionState(force: true);
    }
    return fallback;
  }
}

bool requiresPaywallAuthorityRefresh(SubscriptionState result) {
  if (result.status == 'credits_added') {
    return false;
  }
  if (result.isActive) {
    return true;
  }
  return !const <String>{
    'purchase_pending',
    'purchase_canceled',
    'purchase_cancelled',
    'nothing_to_restore',
    'restore_error',
  }.contains(result.status);
}

final paywallPromptProvider =
    NotifierProvider<PaywallPromptNotifier, PaywallPrompt?>(
      PaywallPromptNotifier.new,
    );

class PaywallPromptNotifier extends Notifier<PaywallPrompt?> {
  @override
  PaywallPrompt? build() => null;

  void set(PaywallPrompt? value) => state = value;
}

class PaywallPrompt {
  const PaywallPrompt({
    required this.title,
    required this.message,
    required this.trigger,
    this.featureId,
    this.remainingCredits,
  });

  final String title;
  final String message;
  final String trigger;
  final String? featureId;
  final int? remainingCredits;
}

final paywallEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(subscriptionPurchasingEnabledProvider)) {
    return false;
  }
  final bool localEnabled = ref.watch(appAccessProvider).paywallEnabled;
  final bool remoteEnabled = ref
      .watch(remotePaywallConfigProvider)
      .maybeWhen(
        data: (RemotePaywallConfig config) => config.enabled,
        orElse: () => true,
      );
  return localEnabled && remoteEnabled;
});
