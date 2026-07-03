import 'package:fantastic_guacamole/data/di/services_providers.dart'
    show sharedPrefsStoreProvider;
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/features/paywall/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/paywall/repositories/paywall_repository.dart';
import 'package:fantastic_guacamole/features/paywall/services/credit_service.dart';
import 'package:fantastic_guacamole/features/paywall/services/paywall_service.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creditServiceProvider = Provider<CreditService>((ref) {
  return CreditService(prefs: ref.read(sharedPrefsStoreProvider));
});

final aiCreditWalletProvider = FutureProvider<AiCreditWallet>((ref) async {
  final bool premium = ref.watch(appAccessProvider).hasPremiumAccess;
  return ref.read(creditServiceProvider).loadWallet(premium: premium);
});

final paywallRepositoryProvider = Provider<IPaywallRepository>((ref) {
  return PaywallRepository();
});

final paywallServiceProvider = Provider<PaywallService>((ref) {
  return PaywallService(ref.read(paywallRepositoryProvider));
});

final paywallConfigProvider = FutureProvider<PaywallEntity>((ref) async {
  return ref.read(paywallServiceProvider).getPaywallConfig();
});

final paywallSubscriptionProvider = FutureProvider<SubscriptionState>((
  ref,
) async {
  return ref.read(paywallServiceProvider).getUserSubscriptionState();
});

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
