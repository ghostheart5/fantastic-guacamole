class PaywallPlan {
  const PaywallPlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.description,
    this.aiCreditsIncluded = 0,
    this.benefits = const <String>[],
    this.isAvailable = true,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String description;
  final int aiCreditsIncluded;
  final List<String> benefits;
  final bool isAvailable;
  final bool isFeatured;
}
