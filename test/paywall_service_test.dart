import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chronospark/core/system/subscription_model.dart';
import 'package:chronospark/data/services/paywall_receipt_verifier.dart';
import 'package:chronospark/data/services/paywall_service.dart';
import 'package:chronospark/data/services/secure_entitlement_store.dart';

class MockPaywallReceiptVerifier extends Mock implements PaywallReceiptVerifier {}

class MockInAppPurchase extends Mock implements InAppPurchase {}

SubscriptionSnapshot _validSnapshot({
  BillingCycle cycle = BillingCycle.monthly,
}) {
  final now = DateTime.now();
  return SubscriptionSnapshot(
    plan: SubscriptionPlan.premium,
    billingCycle: cycle,
    status: SubscriptionStatus.active,
    subscriptionStartDate: now,
    mockNextBillingDate: now.add(const Duration(days: 30)),
  );
}

SubscriptionSnapshot _expiredSnapshot() {
  final past = DateTime.now().subtract(const Duration(days: 1));
  return SubscriptionSnapshot(
    plan: SubscriptionPlan.premium,
    billingCycle: BillingCycle.monthly,
    status: SubscriptionStatus.active,
    subscriptionStartDate: past.subtract(const Duration(days: 30)),
    mockNextBillingDate: past,
  );
}

SubscriptionSnapshot _baseSnapshot() {
  final now = DateTime.now();
  return SubscriptionSnapshot(
    plan: SubscriptionPlan.base,
    billingCycle: BillingCycle.monthly,
    status: SubscriptionStatus.active,
    subscriptionStartDate: now,
    mockNextBillingDate: now.add(const Duration(days: 30)),
  );
}

void main() {
  late InMemoryEntitlementStore store;
  late MockPaywallReceiptVerifier mockVerifier;
  late MockInAppPurchase mockIap;
  late PaywallService sut;

  setUp(() {
    store = InMemoryEntitlementStore();
    mockVerifier = MockPaywallReceiptVerifier();
    mockIap = MockInAppPurchase();
    sut = PaywallService(verifier: mockVerifier, entitlementStore: store, iap: mockIap);
  });

  group('readVerifiedSubscription', () {
    test('returns null when store is empty', () async {
      expect(await sut.readVerifiedSubscription(), isNull);
    });

    test('returns snapshot when store has a valid subscription', () async {
      final snapshot = _validSnapshot();
      await store.writeSubscription(snapshot);

      final result = await sut.readVerifiedSubscription();

      expect(result?.plan, SubscriptionPlan.premium);
      expect(result?.status, SubscriptionStatus.active);
    });

    test('returns null when stored subscription is expired', () async {
      await store.writeSubscription(_expiredSnapshot());
      expect(await sut.readVerifiedSubscription(), isNull);
    });
  });

  group('storeVerifiedSubscription', () {
    test('writes subscription when it is valid', () async {
      await sut.storeVerifiedSubscription(_validSnapshot());

      final stored = await store.readSubscription();
      expect(stored?.plan, SubscriptionPlan.premium);
    });

    test('clears subscription when plan is not premium (base)', () async {
      await store.writeSubscription(_validSnapshot());

      await sut.storeVerifiedSubscription(_baseSnapshot());

      expect(await store.readSubscription(), isNull);
    });

    test('clears subscription when billing date has passed', () async {
      await store.writeSubscription(_validSnapshot());

      await sut.storeVerifiedSubscription(_expiredSnapshot());

      expect(await store.readSubscription(), isNull);
    });

    test('clears subscription when status is pending', () async {
      final now = DateTime.now();
      final pending = SubscriptionSnapshot(
        plan: SubscriptionPlan.premium,
        billingCycle: BillingCycle.monthly,
        status: SubscriptionStatus.pending,
        subscriptionStartDate: now,
        mockNextBillingDate: now.add(const Duration(days: 30)),
      );

      await sut.storeVerifiedSubscription(pending);

      expect(await store.readSubscription(), isNull);
    });
  });

  group('clearVerifiedSubscription', () {
    test('removes a stored subscription', () async {
      await store.writeSubscription(_validSnapshot());

      await sut.clearVerifiedSubscription();

      expect(await store.readSubscription(), isNull);
    });

    test('is a no-op when store is already empty', () async {
      await expectLater(sut.clearVerifiedSubscription(), completes);
    });
  });

  group('SubscriptionSnapshot.isValid', () {
    test('true for active premium with future billing date', () {
      expect(_validSnapshot().isValid, isTrue);
    });

    test('false when plan is base', () {
      expect(_baseSnapshot().isValid, isFalse);
    });

    test('false when billing date is in the past', () {
      expect(_expiredSnapshot().isValid, isFalse);
    });

    test('false when status is expired', () {
      final now = DateTime.now();
      final snap = SubscriptionSnapshot(
        plan: SubscriptionPlan.premium,
        billingCycle: BillingCycle.monthly,
        status: SubscriptionStatus.expired,
        subscriptionStartDate: now,
        mockNextBillingDate: now.add(const Duration(days: 30)),
      );
      expect(snap.isValid, isFalse);
    });

    test('false when status is pending', () {
      final now = DateTime.now();
      final snap = SubscriptionSnapshot(
        plan: SubscriptionPlan.premium,
        billingCycle: BillingCycle.monthly,
        status: SubscriptionStatus.pending,
        subscriptionStartDate: now,
        mockNextBillingDate: now.add(const Duration(days: 30)),
      );
      expect(snap.isValid, isFalse);
    });

    test('yearly plan is also valid premium', () {
      expect(_validSnapshot(cycle: BillingCycle.yearly).isValid, isTrue);
    });
  });

  group('SubscriptionSnapshot serialization', () {
    test('round-trips toJson/fromJson for monthly premium', () {
      final original = _validSnapshot();
      final restored = SubscriptionSnapshot.fromJson(original.toJson());

      expect(restored.plan, original.plan);
      expect(restored.billingCycle, original.billingCycle);
      expect(restored.status, original.status);
    });

    test('round-trips toJson/fromJson for yearly premium', () {
      final original = _validSnapshot(cycle: BillingCycle.yearly);
      final restored = SubscriptionSnapshot.fromJson(original.toJson());

      expect(restored.billingCycle, BillingCycle.yearly);
    });

    test('fromJson returns base plan on missing fields', () {
      final snap = SubscriptionSnapshot.fromJson({});
      expect(snap.plan, SubscriptionPlan.base);
    });
  });
}
