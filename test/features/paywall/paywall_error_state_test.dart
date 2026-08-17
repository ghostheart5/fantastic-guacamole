import 'dart:async';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/services/credit_service.dart';
import 'package:fantastic_guacamole/state/state/intelligence_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// L-27: PaywallPage watched config/subscription/wallet as AsyncValues but
/// only ever checked `.isLoading`, never `.hasError` — a fetch failure fell
/// back silently to an empty-plans paywall with no error banner, retry, or
/// logging. This pins the fixed behavior: an error surfaces a visible banner
/// with a working retry, instead of being swallowed.
void main() {
  Future<ProviderContainer> pumpPaywall(
    WidgetTester tester, {
    required FutureOr<PaywallEntity> Function(Ref ref) config,
    int Function()? onConfigRebuild,
  }) async {
    final _MemorySharedPrefsStore prefs = _MemorySharedPrefsStore();
    final CreditService credit = CreditService(prefs: prefs);

    final ProviderContainer container = ProviderContainer(
      // FutureProviders retry a thrown error with backoff by default
      // (ProviderContainer.defaultRetry); disable it so the failure settles
      // into a stable AsyncError within a single pump.
      retry: (int retryCount, Object error) => null,
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        creditServiceProvider.overrideWithValue(credit),
        intelligenceStateProvider.overrideWithValue(_baseIntelligence),
        paywallConfigProvider.overrideWith((Ref ref) {
          onConfigRebuild?.call();
          return config(ref);
        }),
        paywallSubscriptionProvider.overrideWith(
          (Ref ref) async => const SubscriptionState(
            isActive: false,
            status: 'free',
            source: 'test',
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
    return container;
  }

  testWidgets(
    'a paywall config fetch failure shows the error banner, not a silent fallback',
    (WidgetTester tester) async {
      await pumpPaywall(
        tester,
        config: (Ref ref) async => throw Exception('config failed'),
      );

      expect(
        find.text(
          "Couldn't load the latest plan details. Showing what we have.",
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Retry on the error banner re-fetches the failed provider',
    (WidgetTester tester) async {
      int rebuilds = 0;

      await pumpPaywall(
        tester,
        onConfigRebuild: () => rebuilds++,
        config: (Ref ref) async => throw Exception('config failed'),
      );
      expect(rebuilds, 1);

      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        rebuilds,
        2,
        reason: 'Retry must invalidate the failed provider so it re-fetches.',
      );
    },
  );

  testWidgets('a healthy fetch renders no error banner', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(tester, config: (Ref ref) async => _paywallConfig);

    expect(
      find.text("Couldn't load the latest plan details. Showing what we have."),
      findsNothing,
    );
    expect(find.textContaining('AI CREDITS + PREMIUM'), findsOneWidget);
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
      priceLabel: '45/mo',
      description: 'Test plan',
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
