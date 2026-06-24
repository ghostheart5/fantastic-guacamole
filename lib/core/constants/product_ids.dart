/// Canonical product ID constants for in-app purchases.
///
/// Centralising these prevents typos from causing silent IAP failures and
/// makes it easy to update IDs across the codebase in one place.
abstract final class ProductIds {
  static const String premiumMonthly = 'chronospark_premium_monthly';
  static const String premiumYearly = 'chronospark_premium_yearly';

  /// All recognised product IDs — used for bulk store queries.
  static const Set<String> all = <String>{premiumMonthly, premiumYearly};
}
