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
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
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

/// True when [aiCreditWalletProvider] reads the server wallet that AI chat
/// charges, rather than a count kept on this device.
final aiCreditWalletFromServerProvider = Provider<bool>(
  (ref) => Env.isProduction && ref.watch(aiProxyAvailableProvider),
);

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
  if (ref.watch(aiCreditWalletFromServerProvider)) {
    final client = ref.watch(supabaseClientProvider);
    if (client?.auth.currentUser == null) {
      throw StateError('An authenticated session is required for AI credits.');
    }
    return loadServerAiCreditWallet(
      ref,
      () => client!.rpc<Map<String, dynamic>>('get_credit_wallet_v2'),
    );
  }
  return ref.read(creditServiceProvider).loadWallet(premium: premium);
});

/// Reads the server wallet with [readRow] and tells [aiCreditKnownBalanceProvider]
/// its balance, unless an AI chat answer reported a newer one meanwhile or
/// the account changed.
Future<AiCreditWallet> loadServerAiCreditWallet(
  Ref ref,
  Future<Map<String, dynamic>> Function() readRow,
) async {
  final account = ref.read(accountStorageScopeProvider).v2Namespace;
  final token = ref.read(aiCreditKnownBalanceProvider.notifier).beginRead();
  final wallet = serverAiCreditWallet(
    Map<String, dynamic>.from(await readRow()),
  );
  if (ref.mounted) {
    ref
        .read(aiCreditKnownBalanceProvider.notifier)
        .reportWallet(account, token, wallet.balance);
  }
  return wallet;
}

int _aiCreditBalanceClock = 0;

/// The current AI credit balance of the signed-in account, as far as this
/// app run knows it, or null when it cannot know it. Kept in memory only;
/// watching it never contacts the server.
///
/// The rule: the balance is shown only while nothing is running and nothing
/// has happened that it does not include. Every event forgets it, except
/// the two that may set it. A server wallet read sets it when no request is
/// in the paid step and nothing happened since the read began. An AI chat
/// answer (the balance when its request was reserved) sets it when its
/// request first entered the paid step in this run, no other request is in
/// the paid step, and no outside change has happened since that first
/// attempt. An outside change, for a request, is anything not about that
/// request itself: a wallet read or wallet change (purchase, restore,
/// changed subscription, test charge, Get credits), or another request
/// entering the paid step, answering, failing (also after it was released,
/// which may have refunded it) or being released. A request
/// stops counting as in the paid step when its answer or failure arrives or
/// when it is released (its outcome shown or dropped, it is abandoned, or
/// its execution completes with nobody waiting). A request recovered from an
/// earlier run has no first attempt here, so its answer never sets it. An
/// account or sign-in change, or the account fence, empties everything.
final aiCreditKnownBalanceProvider =
    NotifierProvider<AiCreditKnownBalance, int?>(AiCreditKnownBalance.new);

class AiCreditKnownBalance extends Notifier<int?> {
  String? _account;
  // Changes on every event. A wallet read that began before the latest
  // event is not taken.
  int _version = 0;
  // Requests whose first attempt in this run entered the paid step, and
  // whether an outside change has happened since.
  final _overtaken = <String, bool>{};
  // Requests in the paid step whose answer has not arrived.
  final _running = <String>{};

  @override
  int? build() {
    _account = ref.watch(
      accountStorageScopeProvider.select((scope) => scope.v2Namespace),
    );
    ref.watch(authSessionBoundaryProvider.select((b) => b.generation));
    _version = ++_aiCreditBalanceClock;
    _overtaken.clear();
    _running.clear();
    return null;
  }

  /// Marks the start of a server wallet read.
  int beginRead() => _version;

  /// A request for [account] is handed on for a reply. [firstAttempt] is
  /// false for a retry or a recovery, which keeps the first attempt's mark.
  void enterPaid(
    String account,
    String requestId, {
    required bool firstAttempt,
  }) {
    if (account != _account) return;
    _event(requestId);
    if (firstAttempt) _overtaken.putIfAbsent(requestId, () => false);
    _running.add(requestId);
  }

  /// The answer to [requestId] reported [balance].
  void reportAnswer(String account, String requestId, int balance) {
    if (account != _account) return;
    _running.remove(requestId);
    _event(requestId);
    if (_overtaken[requestId] == false && _running.isEmpty && balance >= 0) {
      state = balance;
    }
  }

  /// [requestId] failed without saying what the balance is now.
  void forget(String account, String requestId) {
    if (account != _account) return;
    _running.remove(requestId);
    _event(requestId);
  }

  /// The app will not use [requestId]'s answer (it was shown, dropped or
  /// abandoned), or its execution completed. Its charge may still have
  /// happened, so this is an outside change for other requests; it no
  /// longer keeps later answers from setting the balance. A request that is
  /// not running is left alone, unless its execution [failed]: a failure
  /// arriving after it was abandoned may have refunded its charge, which no
  /// later figure includes.
  void release(String requestId, {bool failed = false}) {
    if (!_running.remove(requestId) && !failed) return;
    _event(requestId);
  }

  /// The wallet may have changed away from AI chat.
  void walletChanged() => _event(null);

  /// A server wallet read for [account] that began at [token] finished.
  void reportWallet(String? account, int token, int balance) {
    if (account == null || account != _account) return;
    final current = token == _version && _running.isEmpty && balance >= 0;
    _event(null);
    if (current) state = balance;
  }

  /// Every event forgets the balance and is an outside change for every
  /// marked request other than [requestId].
  void _event(String? requestId) {
    _version = ++_aiCreditBalanceClock;
    for (final id in _overtaken.keys.toList()) {
      if (id != requestId) _overtaken[id] = true;
    }
    state = null;
  }
}

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

/// Purchase outcomes that report nothing granted or taken back yet: the
/// purchase is still waiting, was not verified, or failed. Some of these
/// repeat on every routine recheck while a purchase waits.
const _outcomesWithoutWalletChange = {
  'purchase_pending',
  'customer_resolution_required',
  'checkout_unresolved',
  'verification_failed',
  'purchase_failed',
  'restore_error',
  'nothing_to_restore',
};

/// Forgets the known AI credit balance when a purchase outcome for the
/// signed-in account may have changed the server wallet (credits added, a
/// verified subscription, a canceled or refunded purchase), wherever it
/// completes: Google Play's purchase updates, or the routine recheck that
/// finishes a waiting credit purchase. Watched by the app root so it runs
/// for the whole app run, not only while the plans screen is open; that
/// screen forgetting it too is harmless.
final aiCreditPurchaseOutcomeWatchProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<SubscriptionState>>(paywallPurchaseOutcomeProvider, (
    _,
    next,
  ) {
    final outcome = next.asData?.value;
    if (outcome == null ||
        _outcomesWithoutWalletChange.contains(outcome.status)) {
      return;
    }
    ref.read(aiCreditKnownBalanceProvider.notifier).walletChanged();
  });
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
          '${creditsEnabled ? 'Choose a step and Chat can use external AI after you review the app context and confirm the credit price. Settings also offers fictional credit tests. On-device tools remain available.' : 'AI and credit spending are unavailable in this build.'}',
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
      final authority = await authorityRefresher.refreshSubscriptionState(
        force: true,
      );
      // Keep refreshed access authoritative while retaining the receipt
      // rejection for the operation's message. Cached access cannot survive
      // revocation, and an existing entitlement does not verify this receipt.
      if (fallback.status == 'verification_failed') {
        return SubscriptionState(
          isActive: authority.isActive,
          status: fallback.status,
          source: authority.source,
          planId: authority.planId,
          renewalDate: authority.renewalDate,
          isTesting: authority.isTesting,
        );
      }
      return authority;
    }
    return fallback;
  }
}

bool requiresPaywallAuthorityRefresh(SubscriptionState result) {
  if (result.status == 'credits_added' ||
      result.status == 'checkout_unresolved') {
    return false;
  }
  if (result.isActive) {
    return true;
  }
  return !const <String>{
    'purchase_pending',
    'customer_resolution_required',
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
