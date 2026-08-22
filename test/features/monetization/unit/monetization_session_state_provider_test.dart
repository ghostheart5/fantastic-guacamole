import 'dart:async';

import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart';
import 'package:fantastic_guacamole/features/monetization/application/monetization_session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  test('session invalidation clears the account-scoped paywall prompt', () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);

    container
        .read(paywallPromptProvider.notifier)
        .set(
          const PaywallPrompt(
            title: 'A',
            message: 'User A prompt',
            trigger: 'test',
          ),
        );
    expect(container.read(paywallPromptProvider)?.title, 'A');

    final Provider<void> invalidateSession = Provider<void>((Ref ref) {
      invalidateMonetizationSessionState(ref);
    });
    container.read(invalidateSession);

    expect(container.read(paywallPromptProvider), isNull);
  });

  test('repeated session invalidation is safe', () {
    final ProviderContainer container = _container();
    addTearDown(container.dispose);

    final Provider<void> invalidateSession = Provider<void>((Ref ref) {
      invalidateMonetizationSessionState(ref);
    });
    container.read(invalidateSession);
    container.invalidate(invalidateSession);
    container.read(invalidateSession);

    expect(container.read(paywallPromptProvider), isNull);
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      purchaseRepositoryProvider.overrideWithValue(_FakePurchaseRepository()),
    ],
  );
}

class _FakePurchaseRepository implements PurchaseRepository {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack) {
    throw UnsupportedError('not used by the session coordinator test');
  }

  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) {
    throw UnsupportedError('not used by the session coordinator test');
  }

  @override
  Future<PurchaseResult> restorePurchases() {
    throw UnsupportedError('not used by the session coordinator test');
  }
}
