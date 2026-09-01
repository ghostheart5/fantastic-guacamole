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

/// Covers the loading branch, restore availability, plan prioritization,
/// truthful result messages, and the dormant offer-copy contract.
void main() {
  Future<ProviderContainer> pumpPaywall(
    WidgetTester tester, {
    required PaywallEntity config,
    FutureOr<PaywallEntity> Function(Ref ref)? configOverride,
    SubscriptionState subscription = const SubscriptionState(
      isActive: false,
      status: 'free',
      source: 'test',
      isTesting: false,
    ),
  }) async {
    // Restore Purchases and Show all plans sit below the
    // fold at the default 800x600 test viewport, and PaywallPage's ListView
    // only inflates elements that scroll into view — a tall surface renders
    // the whole scroll view at once (same landmine worked around in
    // nexus_navigation_test.dart / progression_screen_test.dart).
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final _MemorySharedPrefsStore prefs = _MemorySharedPrefsStore();
    final CreditService credit = CreditService(prefs: prefs);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        creditServiceProvider.overrideWithValue(credit),
        intelligenceStateProvider.overrideWithValue(_baseIntelligence),
        paywallConfigProvider.overrideWith(
          configOverride ?? (Ref ref) async => config,
        ),
        paywallSubscriptionProvider.overrideWith(
          (Ref ref) async => subscription,
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

  testWidgets('shows a spinner while config/subscription/wallet are loading', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(
      tester,
      config: _twoPlanConfig,
      // A never-completing future keeps the page in its loading branch for
      // the full test, so the spinner (not the paywall body) is what renders.
      configOverride: (Ref ref) => Completer<PaywallEntity>().future,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Restore Purchases'), findsNothing);
  });

  testWidgets('Restore Purchases stays disabled during containment', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(tester, config: _twoPlanConfig);

    final OutlinedButton button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Restore Purchases'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('active subscription disables every plan purchase action', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(
      tester,
      config: _twoPlanConfig,
      subscription: const SubscriptionState(
        isActive: true,
        status: 'active',
        source: 'google_play_server',
        planId: 'monthly',
      ),
    );

    expect(find.text('Current subscription active'), findsNWidgets(2));
    for (final FilledButton button in tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    )) {
      expect(button.onPressed, isNull);
    }
  });

  test('restore availability is independent of product catalog results', () {
    expect(
      _noAvailablePlanConfig.plans.any((PaywallPlan plan) => plan.isAvailable),
      isFalse,
    );
    expect(
      resolvePaywallRestoreAvailability(paidCreditPlansEnabled: true),
      isTrue,
    );
    expect(
      resolvePaywallRestoreAvailability(paidCreditPlansEnabled: false),
      isFalse,
    );
  });

  testWidgets(
    'Show all plans reveals the deprioritized plan, and collapses back',
    (WidgetTester tester) async {
      await pumpPaywall(tester, config: _threePlanConfig);

      // Prioritization narrows 3 plans (1 featured) down to 2, so the third
      // plan's title starts out hidden.
      expect(find.text('Show all plans'), findsOneWidget);
      expect(find.text('Third Tier'), findsNothing);

      await tester.tap(find.text('Show all plans'));
      await tester.pump();

      expect(find.text('Third Tier'), findsOneWidget);
      expect(find.text('Show fewer plans'), findsOneWidget);

      await tester.tap(find.text('Show fewer plans'));
      await tester.pump();

      expect(find.text('Third Tier'), findsNothing);
      expect(find.text('Show all plans'), findsOneWidget);
    },
  );

  testWidgets('renders only the supported allowance offer claims', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(tester, config: _twoPlanConfig);

    expect(
      find.text('Credits after a verified purchase or paid renewal: 300'),
      findsOneWidget,
    );
    expect(
      find.text('Credits after a verified purchase or paid renewal: 360'),
      findsOneWidget,
    );
    expect(find.textContaining('credits per month'), findsNothing);
    expect(
      find.textContaining(
        'Google Play confirms billing frequency and renewal terms',
      ),
      findsWidgets,
    );
    expect(find.textContaining('BEST VALUE'), findsNothing);
    expect(find.textContaining('Preview Premium'), findsNothing);
    expect(find.textContaining('Deeper memory'), findsNothing);
    expect(find.textContaining('advanced agents'), findsNothing);
  });

  test('pending and canceled purchase copy preserves current access', () {
    expect(
      resolvePaywallPurchaseResultMessage(
        const SubscriptionState(
          isActive: false,
          status: 'purchase_pending',
          source: 'google_play',
          planId: 'monthly',
        ),
        testingMode: false,
      ),
      'Purchase pending. Your current access stays unchanged while Google Play completes it.',
    );
    expect(
      resolvePaywallPurchaseResultMessage(
        const SubscriptionState(
          isActive: false,
          status: 'purchase_canceled',
          source: 'google_play',
          planId: 'monthly',
        ),
        testingMode: false,
      ),
      'Purchase canceled. Your current access was not changed.',
    );
  });

  test('verification failure copy preserves current access', () {
    expect(
      resolvePaywallPurchaseResultMessage(
        const SubscriptionState(
          isActive: false,
          status: 'verification_failed',
          source: 'google_play',
          planId: 'monthly',
        ),
        testingMode: false,
      ),
      'Purchase verification could not be confirmed. Your current access stays unchanged; use Restore Purchases to retry.',
    );
  });

  test('acknowledgement failure never claims activation', () {
    expect(
      resolvePaywallPurchaseResultMessage(
        const SubscriptionState(
          isActive: false,
          status: 'acknowledgement_failed',
          source: 'google_play',
          planId: 'monthly',
        ),
        testingMode: false,
      ),
      'Purchase verification succeeded, but final acknowledgement is still pending. Your current access stays unchanged; use Restore Purchases to retry.',
    );
  });

  test('inactive manual restore reports nothing to restore', () {
    expect(
      resolvePaywallRestoreResultMessage(
        const SubscriptionState(
          isActive: false,
          status: 'nothing_to_restore',
          source: 'supabase_authority',
        ),
        testingMode: false,
      ),
      'No active purchases were found to restore.',
    );
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
  auth: AuthStateSnapshot(hasMockSignIn: true, hasAuthenticatedUser: true),
  mockLogin: MockLoginConfigState(email: '', password: ''),
);

const PaywallEntity _twoPlanConfig = PaywallEntity(
  featureId: 'premium',
  title: 'External-assistant credit plans',
  body:
      'Google Play provides price, billing frequency, and renewal terms before purchase.',
  plans: <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Monthly',
      priceLabel: '45/mo',
      description: 'Test plan',
      aiCreditsIncluded: 300,
      isAvailable: true,
      isFeatured: true,
    ),
    PaywallPlan(
      id: 'annual',
      title: 'Annual',
      priceLabel: '399/yr',
      description: 'Test annual plan',
      aiCreditsIncluded: 360,
      benefits: <String>[
        'Increases external-assistant credit allowance to 360 credits per month',
      ],
      isAvailable: true,
      isFeatured: false,
    ),
  ],
  isUnlocked: false,
);

const PaywallEntity _threePlanConfig = PaywallEntity(
  featureId: 'premium',
  title: 'External-assistant credit plans',
  body:
      'Google Play provides price, billing frequency, and renewal terms before purchase.',
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
    PaywallPlan(
      id: 'annual',
      title: 'Annual',
      priceLabel: '399/yr',
      description: 'Test annual plan',
      aiCreditsIncluded: 1200,
      isAvailable: true,
      isFeatured: false,
    ),
    PaywallPlan(
      id: 'third-tier',
      title: 'Third Tier',
      priceLabel: '999/yr',
      description: 'Deprioritized plan',
      aiCreditsIncluded: 5000,
      isAvailable: true,
      isFeatured: false,
    ),
  ],
  isUnlocked: false,
);

const PaywallEntity _noAvailablePlanConfig = PaywallEntity(
  featureId: 'premium',
  title: 'External-assistant credit plans',
  body:
      'Google Play provides price, billing frequency, and renewal terms before purchase.',
  plans: <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Monthly',
      priceLabel: '45/mo',
      description: 'Test plan',
      aiCreditsIncluded: 100,
      isAvailable: false,
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
