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

/// Fills the widget-test gaps the Phase 5 survey identified for Paywall:
/// the loading branch, the Restore Purchases enable/disable rule, the
/// Show-all-plans toggle, and the comparison ExpansionTile.
void main() {
  Future<ProviderContainer> pumpPaywall(
    WidgetTester tester, {
    required PaywallEntity config,
    FutureOr<PaywallEntity> Function(Ref ref)? configOverride,
  }) async {
    // Restore Purchases / Show all plans / comparison tile all sit below the
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

  testWidgets('Restore Purchases is enabled when a plan is available', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(tester, config: _twoPlanConfig);

    final OutlinedButton button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Restore Purchases'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Restore Purchases is disabled when no plan is available', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(tester, config: _noAvailablePlanConfig);

    final OutlinedButton button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Restore Purchases'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
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

  testWidgets('the comparison ExpansionTile expands and collapses', (
    WidgetTester tester,
  ) async {
    await pumpPaywall(tester, config: _twoPlanConfig);

    expect(find.text('Compare Free vs Premium'), findsOneWidget);
    expect(find.text('Keep the habit alive'), findsNothing);

    // AnimatedSystemBackground drives a continuously-repeating animation, so
    // pumpAndSettle() would never settle; pump past ExpansionTile's own
    // (much shorter) expand/collapse transition instead.
    await tester.tap(find.text('Compare Free vs Premium'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Keep the habit alive'), findsOneWidget);

    await tester.tap(find.text('Compare Free vs Premium'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Keep the habit alive'), findsNothing);
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
    PaywallPlan(
      id: 'annual',
      title: 'Annual',
      priceLabel: '399/yr',
      description: 'Test annual plan',
      aiCreditsIncluded: 1200,
      isAvailable: true,
      isFeatured: false,
    ),
  ],
  isUnlocked: false,
);

const PaywallEntity _threePlanConfig = PaywallEntity(
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
  title: 'AI Credits + Premium',
  body: 'Unlock premium intelligence flows.',
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
