import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/state/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('base quota blocks when exhausted and premium upgrade bypasses gate', (
    WidgetTester tester,
  ) async {
    final _MemorySharedPrefsStore prefs = _MemorySharedPrefsStore();
    final CreditService credit = CreditService(prefs: prefs);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        creditServiceProvider.overrideWithValue(credit),
        intelligenceStateProvider.overrideWithValue(_baseIntelligence),
        paywallConfigProvider.overrideWith((Ref ref) async => _paywallConfig),
        paywallSubscriptionProvider.overrideWith(
          (Ref ref) async => const SubscriptionState(
            isActive: false,
            status: 'free',
            source: 'integration',
            isTesting: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PaywallPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('AI CREDITS + PREMIUM'), findsOneWidget);

    final AiCreditWallet before = await container.read(aiCreditWalletProvider.future);
    final AiCreditSpendResult firstSpend = await credit.spend(premium: false, amount: 1);
    final AiCreditWallet afterFirst = await credit.loadWallet(premium: false);

    expect(firstSpend.allowed, isTrue);
    expect(afterFirst.balance, lessThan(before.balance));

    final AiCreditSpendResult exhausted = await credit.spend(
      premium: false,
      amount: afterFirst.balance + 5,
    );
    expect(exhausted.allowed, isFalse);

    container
        .read(paywallPromptProvider.notifier)
        .set(
          PaywallPrompt(
            title: 'AI credits exhausted',
            message: 'Upgrade to continue premium coaching.',
            trigger: 'ai_credit_limit',
            remainingCredits: exhausted.wallet.balance,
          ),
        );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AI credits exhausted'), findsOneWidget);

    container.read(runtimePremiumAccessProvider.notifier).set(true);
    final AiCreditWallet premiumWallet = await credit.loadWallet(premium: true);
    final AiCreditSpendResult premiumSpend = await credit.spend(
      premium: true,
      amount: (premiumWallet.balance / 2).round(),
    );

    expect(container.read(appAccessProvider).hasPremiumAccess, isTrue);
    expect(premiumSpend.allowed, isTrue);
  });
}

const IntelligenceState _baseIntelligence = IntelligenceState(
  environment: EnvironmentState(
    appName: 'ChronoSpark',
    appFlavor: 'test',
    isProduction: false,
    isSupabaseConfigured: false,
  ),
  flags: FeatureFlagsState(
    verboseLogs: false,
    analyticsEnabled: false,
    mockMode: false,
    mockLoginEnabled: false,
    paywallDisabled: false,
    testerFullAccess: false,
  ),
  auth: AuthStateSnapshot(hasMockSession: true, hasAuthenticatedUser: true),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

const PaywallEntity _paywallConfig = PaywallEntity(
  featureId: 'premium',
  title: 'AI Credits + Premium',
  body: 'Unlock premium intelligence flows.',
  plans: <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Monthly',
      priceLabel: '45/mo',
      description: 'Integration plan',
      aiCreditsIncluded: 100,
      isAvailable: true,
      isFeatured: true,
    ),
  ],
  isUnlocked: false,
);

class _MemorySharedPrefsStore implements SharedPrefsStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> init() async {}

  @override
  String? load(String key) {
    return _store[key];
  }

  @override
  Future<void> save(String key, String value) async {
    _store[key] = value;
  }
}
