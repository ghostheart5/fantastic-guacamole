// Mock billing service for ChronoSpark.
// Simulates the payment processor (Stripe / App Store / Play Store) without
// using real payment APIs. Its sole job is to process a charge and return a
// receipt token. Entitlement decisions are made by the server, not here.

import 'dart:math';

import 'subscription_model.dart';

class BillingException implements Exception {
  BillingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Mock payment-processor service.
///
/// In a server-authoritative system the billing processor has one
/// responsibility: collect payment and return a receipt. The server then
/// validates that receipt and decides what the user is allowed to access.
/// This separation prevents the client from self-granting entitlements.
class MockBillingService {
  MockBillingService({this.shouldSucceed = true});

  /// Control whether simulated charges succeed or fail.
  bool shouldSucceed;

  static final Random _random = Random.secure();

  /// Simulate charging the user for a plan upgrade.
  ///
  /// Returns an opaque purchase receipt token on success. Pass this token to
  /// [EntitlementService.activateEntitlement] so the server can validate the
  /// transaction and issue an authoritative entitlement record. Never use this
  /// method's return value to decide whether a feature is unlocked — only the
  /// server's response should determine that.
  Future<String> upgradeToPlan(
    SubscriptionPlan plan,
    BillingCycle billingCycle, {
    bool simulateFailure = false,
  }) async {
    // Simulate payment-processor round-trip delay.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (simulateFailure || !shouldSucceed) {
      throw BillingException('Simulated payment failure. Please try again.');
    }

    if (plan == SubscriptionPlan.base) {
      throw BillingException('Cannot purchase Base tier — it is free.');
    }

    // Return a receipt token the server will validate.
    // In production this would be the App Store receipt, Play Store purchase
    // token, or Stripe payment intent ID.
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final String token = List<String>.generate(
      24,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
    return 'mock_rcpt_${plan.name}_${billingCycle.name}_$token';
  }

  /// Get current subscription pricing
  PricingInfo getPricingInfo(SubscriptionPlan plan, BillingCycle cycle) {
    final SubscriptionTier tier = SubscriptionFeatures.tiers.firstWhere(
      (SubscriptionTier t) => t.plan == plan,
    );

    final double price = cycle == BillingCycle.monthly ? tier.monthlyPrice : tier.yearlyPrice;

    final double monthlyEquivalent = cycle == BillingCycle.monthly ? price : price / 12;

    final double savings = cycle == BillingCycle.yearly ? (tier.monthlyPrice * 12) - price : 0.0;

    return PricingInfo(
      plan: plan,
      cycle: cycle,
      price: price,
      monthlyEquivalent: monthlyEquivalent,
      savings: savings,
    );
  }

  /// Get all available subscription tiers with pricing
  List<SubscriptionTierInfo> getAllTiersWithPricing(BillingCycle cycle) {
    return SubscriptionFeatures.tiers.map((SubscriptionTier tier) {
      final double price = cycle == BillingCycle.monthly ? tier.monthlyPrice : tier.yearlyPrice;

      return SubscriptionTierInfo(
        plan: tier.plan,
        displayName: tier.displayName,
        price: price,
        cycle: cycle,
        features: tier.features,
        isBestValue: tier.plan == SubscriptionPlan.ultimate,
      );
    }).toList();
  }
}

/// Pricing information for a specific plan
class PricingInfo {
  const PricingInfo({
    required this.plan,
    required this.cycle,
    required this.price,
    required this.monthlyEquivalent,
    required this.savings,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final double price;
  final double monthlyEquivalent;
  final double savings;

  String get displayPrice => '\$${price.toStringAsFixed(2)}';
  String get displayMonthlyEquivalent => '\$${monthlyEquivalent.toStringAsFixed(2)}/mo';
  String get displaySavings => '\$${savings.toStringAsFixed(2)}';
}

/// Subscription tier with current pricing
class SubscriptionTierInfo {
  const SubscriptionTierInfo({
    required this.plan,
    required this.displayName,
    required this.price,
    required this.cycle,
    required this.features,
    required this.isBestValue,
  });

  final SubscriptionPlan plan;
  final String displayName;
  final double price;
  final BillingCycle cycle;
  final List<String> features;
  final bool isBestValue;

  String get displayPrice {
    if (price == 0) return 'Free';
    return '\$${price.toStringAsFixed(2)}/${cycle == BillingCycle.monthly ? 'mo' : 'yr'}';
  }
}
