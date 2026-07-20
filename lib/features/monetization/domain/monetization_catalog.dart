import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart';

class FeatureComparisonRow {
  const FeatureComparisonRow({
    required this.feature,
    required this.freeValue,
    required this.monthlyValue,
    required this.yearlyValue,
    required this.lifetimeValue,
  });

  final String feature;
  final String freeValue;
  final String monthlyValue;
  final String yearlyValue;
  final String lifetimeValue;
}

class MonetizationCatalog {
  const MonetizationCatalog._();

  static const SubscriptionPlan freePlan = SubscriptionPlan(
    id: 'free',
    kind: SubscriptionPlanKind.free,
    productId: null,
    title: 'Free Plan',
    subtitle: 'Core planning with limited SI usage',
    priceLabel: 'Free',
    billingLabel: 'Always free',
    includedCredits: 20,
    featureIds: <String>[
      'basic_tasks',
      'basic_goals',
      'basic_habits',
      'basic_timeline',
      'limited_si',
    ],
  );

  static const List<SubscriptionPlan> plans = <SubscriptionPlan>[
    SubscriptionPlan(
      id: 'premium_monthly',
      kind: SubscriptionPlanKind.premiumMonthly,
      productId: 'chronospark_premium_monthly',
      title: 'Premium Monthly',
      subtitle: 'Full premium unlock with 250 AI credits every month',
      priceLabel: 'See Google Play',
      billingLabel: '250 AI credits / month',
      includedCredits: 250,
      featureIds: <String>[
        'full_si_engine',
        'smart_coach',
        'memory_engine',
        'advanced_analytics',
        'premium_themes',
      ],
      isFeatured: true,
    ),
    SubscriptionPlan(
      id: 'premium_yearly',
      kind: SubscriptionPlanKind.premiumYearly,
      productId: 'chronospark_premium_annual',
      title: 'Premium Yearly',
      subtitle: 'Annual premium with 4000 AI credits per year',
      priceLabel: 'See Google Play',
      billingLabel: '4000 AI credits / year',
      includedCredits: 4000,
      featureIds: <String>[
        'full_si_engine',
        'smart_coach',
        'memory_engine',
        'advanced_analytics',
        'premium_themes',
      ],
    ),
    SubscriptionPlan(
      id: 'lifetime',
      kind: SubscriptionPlanKind.lifetime,
      productId: 'chronospark_lifetime',
      title: 'Lifetime',
      subtitle: 'Permanent premium entitlement and 1000 starter AI credits',
      priceLabel: 'See Google Play',
      billingLabel: '1000 starter AI credits',
      includedCredits: 1000,
      featureIds: <String>[
        'full_si_engine',
        'smart_coach',
        'memory_engine',
        'advanced_analytics',
        'premium_themes',
      ],
    ),
  ];

  static const List<AiCreditPackage> creditPackages = <AiCreditPackage>[
    AiCreditPackage(
      id: 'credits_100',
      productId: 'chronospark_credits_100',
      title: '100 Credits',
      credits: 100,
      bonusCredits: 0,
      priceLabel: 'See Google Play',
      description: 'Quick top-up for short coaching bursts.',
    ),
    AiCreditPackage(
      id: 'credits_500_bonus',
      productId: 'chronospark_credits_500',
      title: '500 Credits + Bonus',
      credits: 500,
      bonusCredits: 75,
      priceLabel: 'See Google Play',
      description: 'Best for regular deep planning sessions.',
      isFeatured: true,
    ),
    AiCreditPackage(
      id: 'credits_1200_bonus',
      productId: 'chronospark_credits_1200',
      title: '1200 Credits + Bonus',
      credits: 1200,
      bonusCredits: 200,
      priceLabel: 'See Google Play',
      description: 'Optimized for heavy creator and memory usage.',
    ),
    AiCreditPackage(
      id: 'credits_3000_bonus',
      productId: 'chronospark_credits_3000',
      title: '3000 Credits + Bonus',
      credits: 3000,
      bonusCredits: 600,
      priceLabel: 'See Google Play',
      description: 'Maximum long-horizon reserve for power users.',
    ),
  ];

  static const List<FeatureComparisonRow> comparisonRows =
      <FeatureComparisonRow>[
        FeatureComparisonRow(
          feature: 'Tasks',
          freeValue: 'Basic',
          monthlyValue: 'Full',
          yearlyValue: 'Full',
          lifetimeValue: 'Full',
        ),
        FeatureComparisonRow(
          feature: 'Goals',
          freeValue: 'Basic',
          monthlyValue: 'Full',
          yearlyValue: 'Full',
          lifetimeValue: 'Full',
        ),
        FeatureComparisonRow(
          feature: 'Habits',
          freeValue: 'Basic',
          monthlyValue: 'Full',
          yearlyValue: 'Full',
          lifetimeValue: 'Full',
        ),
        FeatureComparisonRow(
          feature: 'Timeline',
          freeValue: 'Basic',
          monthlyValue: 'Advanced',
          yearlyValue: 'Advanced',
          lifetimeValue: 'Advanced',
        ),
        FeatureComparisonRow(
          feature: 'SI Engine',
          freeValue: 'Limited',
          monthlyValue: 'Full',
          yearlyValue: 'Full',
          lifetimeValue: 'Full',
        ),
        FeatureComparisonRow(
          feature: 'Smart Coach',
          freeValue: 'No',
          monthlyValue: 'Yes',
          yearlyValue: 'Yes',
          lifetimeValue: 'Yes',
        ),
        FeatureComparisonRow(
          feature: 'Memory Engine',
          freeValue: 'No',
          monthlyValue: 'Yes',
          yearlyValue: 'Yes',
          lifetimeValue: 'Yes',
        ),
        FeatureComparisonRow(
          feature: 'Advanced Analytics',
          freeValue: 'No',
          monthlyValue: 'Yes',
          yearlyValue: 'Yes',
          lifetimeValue: 'Yes',
        ),
        FeatureComparisonRow(
          feature: 'Premium Themes',
          freeValue: 'No',
          monthlyValue: 'Yes',
          yearlyValue: 'Yes',
          lifetimeValue: 'Yes',
        ),
      ];
}