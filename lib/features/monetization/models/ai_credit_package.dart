class AiCreditPackage {
  const AiCreditPackage({
    required this.id,
    required this.productId,
    required this.title,
    required this.credits,
    required this.bonusCredits,
    required this.priceLabel,
    required this.description,
    this.isFeatured = false,
    this.isAvailable = true,
  });

  final String id;
  final String productId;
  final String title;
  final int credits;
  final int bonusCredits;
  final String priceLabel;
  final String description;
  final bool isFeatured;
  final bool isAvailable;

  int get totalCredits => credits + bonusCredits;

  AiCreditPackage copyWith({String? priceLabel, bool? isAvailable}) {
    return AiCreditPackage(
      id: id,
      productId: productId,
      title: title,
      credits: credits,
      bonusCredits: bonusCredits,
      priceLabel: priceLabel ?? this.priceLabel,
      description: description,
      isFeatured: isFeatured,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}