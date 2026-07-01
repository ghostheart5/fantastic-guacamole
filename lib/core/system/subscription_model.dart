// Subscription and billing models for ChronoSpark.
// Supports Base (free with trials), Premium, and Ultimate tiers.

enum SubscriptionPlan { base, premium, ultimate }

enum BillingCycle { monthly, yearly }

enum SubscriptionStatus { active, canceled, expired, pending }

extension SubscriptionPlanDisplay on SubscriptionPlan {
  String get displayName {
    switch (this) {
      case SubscriptionPlan.base:
        return 'Base';
      case SubscriptionPlan.premium:
        return 'Premium';
      case SubscriptionPlan.ultimate:
        return 'Ultimate';
    }
  }

  String get displayPrice {
    switch (this) {
      case SubscriptionPlan.base:
        return 'Free';
      case SubscriptionPlan.premium:
        return 'Premium';
      case SubscriptionPlan.ultimate:
        return 'Ultimate';
    }
  }

  bool get isPremium => this == SubscriptionPlan.premium || this == SubscriptionPlan.ultimate;
  bool get isUltimate => this == SubscriptionPlan.ultimate;
}

extension BillingCycleDisplay on BillingCycle {
  String get displayName => this == BillingCycle.monthly ? 'Monthly' : 'Yearly';

  double get monthlyPrice {
    return this == BillingCycle.monthly ? 7.99 : 99.99 / 12;
  }

  double get totalPrice {
    return this == BillingCycle.monthly ? 7.99 : 99.99;
  }

  int get billingIntervalDays => this == BillingCycle.monthly ? 30 : 365;
}

/// Represents a subscription tier with its features
class SubscriptionTier {
  const SubscriptionTier({
    required this.plan,
    required this.displayName,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
  });

  final SubscriptionPlan plan;
  final String displayName;
  final double monthlyPrice;
  final double yearlyPrice;
  final List<String> features;
}

/// Features available per tier
class SubscriptionFeatures {
  // Base (Free) features
  static const List<String> baseFeatures = <String>[
    'Task creation and management',
    'Basic time-blocking (Temporal Ops)',
    'Limited SI Console access',
    'Adaptive learning (basic)',
    'Last 7 days history',
    '5 Temporal Ops trial opens',
    '8 SI Console trial opens',
  ];

  // Premium features
  static const List<String> premiumFeatures = <String>[
    'All Base features',
    'Unlimited Temporal Ops access',
    'Unlimited SI Console access',
    'Full SI Engine output depth',
    'Full adaptive learning enabled',
    'Extended history (30 days)',
    'Enhanced task suggestions',
    'Faster decision refresh',
    'Priority support',
  ];

  // Ultimate features
  static const List<String> ultimateFeatures = <String>[
    'All Premium features',
    'Unlimited history access',
    'Advanced analytics & trends',
    'Behavior completion graphs',
    'Energy/workload tracking over time',
    'Deep SI insights & predictions',
    'Custom themes & personalization',
    'Advanced tagging & categories',
    'Priority feature access',
    'Early beta features',
  ];

  static List<SubscriptionTier> get tiers => <SubscriptionTier>[
    const SubscriptionTier(
      plan: SubscriptionPlan.base,
      displayName: 'Base',
      monthlyPrice: 0.0,
      yearlyPrice: 0.0,
      features: baseFeatures,
    ),
    const SubscriptionTier(
      plan: SubscriptionPlan.premium,
      displayName: 'Premium',
      monthlyPrice: 7.99,
      yearlyPrice: 59.99,
      features: premiumFeatures,
    ),
    const SubscriptionTier(
      plan: SubscriptionPlan.ultimate,
      displayName: 'Ultimate',
      monthlyPrice: 12.99,
      yearlyPrice: 99.99,
      features: ultimateFeatures,
    ),
  ];
}

/// Subscription state snapshot
class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.plan,
    required this.billingCycle,
    required this.status,
    required this.subscriptionStartDate,
    required this.mockNextBillingDate,
  });

  final SubscriptionPlan plan;
  final BillingCycle billingCycle;
  final SubscriptionStatus status;
  final DateTime subscriptionStartDate;
  final DateTime mockNextBillingDate;

  /// Serialize to JSON for persistence
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'plan': plan.toString().split('.').last,
      'billingCycle': billingCycle.toString().split('.').last,
      'status': status.toString().split('.').last,
      'subscriptionStartDate': subscriptionStartDate.toIso8601String(),
      'mockNextBillingDate': mockNextBillingDate.toIso8601String(),
    };
  }

  /// Deserialize from JSON
  factory SubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    try {
      final String planStr = json['plan'] as String? ?? 'base';
      final String cycleStr = json['billingCycle'] as String? ?? 'monthly';
      final String statusStr = json['status'] as String? ?? 'active';

      return SubscriptionSnapshot(
        plan: SubscriptionPlan.values.firstWhere(
          (SubscriptionPlan e) => e.toString().split('.').last == planStr,
          orElse: () => SubscriptionPlan.base,
        ),
        billingCycle: BillingCycle.values.firstWhere(
          (BillingCycle e) => e.toString().split('.').last == cycleStr,
          orElse: () => BillingCycle.monthly,
        ),
        status: SubscriptionStatus.values.firstWhere(
          (SubscriptionStatus e) => e.toString().split('.').last == statusStr,
          orElse: () => SubscriptionStatus.active,
        ),
        subscriptionStartDate:
            DateTime.tryParse(json['subscriptionStartDate'] as String? ?? '') ?? DateTime.now(),
        mockNextBillingDate:
            DateTime.tryParse(json['mockNextBillingDate'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
      );
    } catch (_) {
      // Return default Base subscription on error
      return SubscriptionSnapshot(
        plan: SubscriptionPlan.base,
        billingCycle: BillingCycle.monthly,
        status: SubscriptionStatus.active,
        subscriptionStartDate: DateTime.now(),
        mockNextBillingDate: DateTime.now().add(const Duration(days: 30)),
      );
    }
  }

  /// Create a default Base subscription
  factory SubscriptionSnapshot.base() {
    return SubscriptionSnapshot(
      plan: SubscriptionPlan.base,
      billingCycle: BillingCycle.monthly,
      status: SubscriptionStatus.active,
      subscriptionStartDate: DateTime.now(),
      mockNextBillingDate: DateTime.now().add(const Duration(days: 30)),
    );
  }

  /// Copy with modified fields
  SubscriptionSnapshot copyWith({
    SubscriptionPlan? plan,
    BillingCycle? billingCycle,
    SubscriptionStatus? status,
    DateTime? subscriptionStartDate,
    DateTime? mockNextBillingDate,
  }) {
    return SubscriptionSnapshot(
      plan: plan ?? this.plan,
      billingCycle: billingCycle ?? this.billingCycle,
      status: status ?? this.status,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      mockNextBillingDate: mockNextBillingDate ?? this.mockNextBillingDate,
    );
  }

  /// Check if subscription is currently valid for premium access.
  bool get isValid =>
      plan.isPremium &&
      status != SubscriptionStatus.pending &&
      status != SubscriptionStatus.expired &&
      DateTime.now().isBefore(mockNextBillingDate);

  /// Days until next billing
  int get daysUntilNextBilling {
    return mockNextBillingDate.difference(DateTime.now()).inDays.clamp(0, 365);
  }

  /// Calculate refund-eligible period (14 days)
  bool get isRefundEligible {
    final Duration elapsed = DateTime.now().difference(subscriptionStartDate);
    return elapsed.inDays < 14;
  }
}
