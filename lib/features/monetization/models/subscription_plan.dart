enum SubscriptionPlanKind { free, premiumMonthly, premiumYearly, lifetime }

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.kind,
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.billingLabel,
    required this.includedCredits,
    required this.featureIds,
    this.isFeatured = false,
    this.isAvailable = true,
  });

  final String id;
  final SubscriptionPlanKind kind;
  final String? productId;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String billingLabel;
  final int includedCredits;
  final List<String> featureIds;
  final bool isFeatured;
  final bool isAvailable;

  bool get isPremium => kind != SubscriptionPlanKind.free;
  bool get isLifetime => kind == SubscriptionPlanKind.lifetime;

  SubscriptionPlan copyWith({String? priceLabel, bool? isAvailable}) {
    return SubscriptionPlan(
      id: id,
      kind: kind,
      productId: productId,
      title: title,
      subtitle: subtitle,
      priceLabel: priceLabel ?? this.priceLabel,
      billingLabel: billingLabel,
      includedCredits: includedCredits,
      featureIds: featureIds,
      isFeatured: isFeatured,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}