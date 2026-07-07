import 'package:fantastic_guacamole/data/di/repositories_providers.dart'
    show appPaywallRepositoryProvider;
import 'package:fantastic_guacamole/data/di/storage_providers.dart'
    show sharedPrefsStoreProvider;
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/get_available_plans.dart';
import 'package:fantastic_guacamole/domain/usecases/restore_purchases.dart';
import 'package:fantastic_guacamole/domain/usecases/start_subscription.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService(prefs: ref.read(sharedPrefsStoreProvider));
});

final aiCreditWalletProvider = FutureProvider<AiCreditWallet>((ref) async {
  final bool premium = ref.watch(appAccessProvider).hasPremiumAccess;
  return ref.read(creditServiceProvider).loadWallet(premium: premium);
});

final paywallRepositoryProvider = Provider<IPaywallRepository>((ref) {
  return ref.read(appPaywallRepositoryProvider);
});

final getAvailablePlansUseCaseProvider = Provider<GetAvailablePlans>((ref) {
  return GetAvailablePlans(ref.read(paywallRepositoryProvider));
});

final startSubscriptionUseCaseProvider = Provider<StartSubscription>((ref) {
  return StartSubscription(ref.read(paywallRepositoryProvider));
});

final restorePurchasesUseCaseProvider = Provider<RestorePurchases>((ref) {
  return RestorePurchases(ref.read(paywallRepositoryProvider));
});

final paywallActionsProvider = Provider<PaywallActions>((ref) {
  return PaywallActions(ref);
});

final paywallSubscriptionProvider = FutureProvider<SubscriptionState>((
  ref,
) async {
  return ref.read(paywallRepositoryProvider).getUserSubscriptionState();
});

final paywallConfigProvider = FutureProvider<PaywallEntity>((ref) async {
  final List<PaywallPlan> plans = await ref
      .read(getAvailablePlansUseCaseProvider)
      .call();
  final SubscriptionState subscription = await ref
      .read(paywallRepositoryProvider)
      .getUserSubscriptionState();
  return PaywallEntity(
    featureId: 'premium',
    title: subscription.isTesting
        ? 'Unlocked for testing'
        : 'AI Credits + Premium',
    body: subscription.isTesting
        ? 'Premium gates are bypassed in this build.'
        : 'Unlock AI credits, premium coaching, deeper memory, and advanced tools.',
    plans: plans,
    isUnlocked: subscription.isActive,
  );
});

class PaywallActions {
  const PaywallActions(this._ref);

  final Ref _ref;

  Future<SubscriptionState> startSubscription(String planId) {
    return _ref.read(startSubscriptionUseCaseProvider).call(planId);
  }

  Future<SubscriptionState> restorePurchases() {
    return _ref.read(restorePurchasesUseCaseProvider).call();
  }
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
  return ref.watch(appAccessProvider).paywallEnabled;
});
