// Mock billing service for ChronoSpark.
// Simulates subscription purchase and management without real payment APIs.
// Perfect for offline testing and demo environments.

import 'subscription_model.dart';

class BillingException implements Exception {
  BillingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Mock billing service that simulates subscription management
class MockBillingService {
  MockBillingService({this.shouldSucceed = true});

  /// Control whether simulated purchases succeed or fail
  bool shouldSucceed;

  /// Simulate upgrading to a plan
  /// Returns updated SubscriptionSnapshot on success
  Future<SubscriptionSnapshot> upgradeToPlan(
    SubscriptionPlan plan,
    BillingCycle billingCycle, {
    bool simulateFailure = false,
  }) async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (simulateFailure || !shouldSucceed) {
      throw BillingException('Simulated payment failure. Please try again.');
    }

    if (plan == SubscriptionPlan.base) {
      throw BillingException('Cannot upgrade to Base tier. Use downgradeToPlan instead.');
    }

    final DateTime now = DateTime.now();
    final int intervalDays = billingCycle.billingIntervalDays;

    return SubscriptionSnapshot(
      plan: plan,
      billingCycle: billingCycle,
      status: SubscriptionStatus.active,
      subscriptionStartDate: now,
      mockNextBillingDate: now.add(Duration(days: intervalDays)),
    );
  }

  /// Simulate downgrading to Base (free) tier
  /// Maintains user data but removes premium features
  Future<SubscriptionSnapshot> downgradeToPlan() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final DateTime now = DateTime.now();

    return SubscriptionSnapshot(
      plan: SubscriptionPlan.base,
      billingCycle: BillingCycle.monthly, // N/A for free tier
      status: SubscriptionStatus.active,
      subscriptionStartDate: now,
      mockNextBillingDate: now.add(const Duration(days: 30)), // Arbitrary future date
    );
  }

  /// Simulate canceling a subscription (moves to canceled status)
  /// Typically used at end of billing cycle
  Future<SubscriptionSnapshot> cancelSubscription(SubscriptionSnapshot current) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    return current.copyWith(status: SubscriptionStatus.canceled);
  }

  /// Simulate subscription renewal (when billing date is reached)
  Future<SubscriptionSnapshot> renewSubscription(SubscriptionSnapshot current) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!shouldSucceed) {
      throw BillingException('Simulated renewal failure. Please update your payment method.');
    }

    final DateTime now = DateTime.now();
    final int intervalDays = current.billingCycle.billingIntervalDays;

    return current.copyWith(
      subscriptionStartDate: now,
      mockNextBillingDate: now.add(Duration(days: intervalDays)),
    );
  }

  /// Simulate applying a promo code (extends billing cycle)
  Future<SubscriptionSnapshot> applyPromoCode(
    SubscriptionSnapshot current,
    String promoCode, {
    int discountDays = 30,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (promoCode.isNotEmpty && promoCode.length >= 3) {
      return current.copyWith(
        mockNextBillingDate: current.mockNextBillingDate.add(Duration(days: discountDays)),
      );
    }

    throw BillingException('Invalid promo code.');
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
