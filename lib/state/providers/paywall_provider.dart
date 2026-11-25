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
/// app run knows it, or null when it cannot know it. Kept in memory only.
/// Watching it never contacts the server, so AI chat can show a balance
/// without causing a wallet read.
///
/// Sources: a server wallet read something else made (Settings, Plans and
/// credits), and an AI chat answer. An answer's figure is the balance when
/// its request was reserved, so it is used only for a request that entered
/// the paid step in this run with nothing reported or forgotten since
/// ([enterPaid]); otherwise the balance is forgotten. Anything that may
/// change the wallet away from AI chat (a purchase, a restore, an
/// entitlement refresh, a test charge) calls [walletChanged]. Empty after
/// any account or sign-in change, and cleared by the account fence.
final aiCreditKnownBalanceProvider =
    NotifierProvider<AiCreditKnownBalance, int?>(AiCreditKnownBalance.new);

class AiCreditKnownBalance extends Notifier<int?> {
  String? _account;
  // Changes whenever the value is set or forgotten. A wallet read or an
  // answer whose request began before the latest change is ignored.
  int _version = 0;
  // Per request id: the version when it entered the paid step in this run.
  final _paidSince = <String, int>{};
  // Requests handed on for a reply whose answer has not arrived yet.
  final _inFlight = <String>{};

  @override
  int? build() {
    _account = ref.watch(
      accountStorageScopeProvider.select((scope) => scope.v2Namespace),
    );
    ref.watch(authSessionBoundaryProvider.select((b) => b.generation));
    _version = ++_aiCreditBalanceClock;
    _paidSince.clear();
    _inFlight.clear();
    return null;
  }

  /// Marks the start of a server wallet read.
  int beginRead() => _version;

  /// A request for [account] is handed on for a reply. Only its first
  /// attempt in this run marks when it entered the paid step: a retry keeps
  /// that mark, and a request recovered from an earlier run has none.
  void enterPaid(
    String account,
    String requestId, {
    required bool firstAttempt,
  }) {
    if (account != _account) return;
    if (firstAttempt) _paidSince.putIfAbsent(requestId, () => _version);
    _inFlight.add(requestId);
  }

  /// A balance the answer to [requestId] reported. Used only when nothing
  /// was reported or forgotten since that request entered the paid step and
  /// no other request is still waiting for its answer (whose reservation
  /// may be newer); otherwise the balance is forgotten.
  void reportAnswer(String account, String requestId, int balance) {
    if (account != _account) return;
    _inFlight.remove(requestId);
    final since = _paidSince[requestId];
    if (since == null ||
        since != _version ||
        _inFlight.isNotEmpty ||
        balance < 0) {
      _forget(requestId);
      return;
    }
    _version = ++_aiCreditBalanceClock;
    _paidSince[requestId] = _version;
    state = balance;
  }

  /// The request [requestId] for [account] may have changed the balance
  /// without saying what it is now: show none until it is known again.
  void forget(String account, String requestId) {
    if (account != _account) return;
    _inFlight.remove(requestId);
    _forget(requestId);
  }

  /// The wallet may have changed away from AI chat.
  void walletChanged() => _forget(null);

  void _forget(String? requestId) {
    _version = ++_aiCreditBalanceClock;
    // This request's own outcome is not a change it has to be older than.
    if (requestId != null && _paidSince.containsKey(requestId)) {
      _paidSince[requestId] = _version;
    }
    state = null;
  }

  /// A server wallet read for [account] that began at [token] finished.
  void reportWallet(String? account, int token, int balance) {
    if (account == null ||
        account != _account ||
        token != _version ||
        balance < 0) {
      return;
    }
    _version = ++_aiCreditBalanceClock;
    state = balance;
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
