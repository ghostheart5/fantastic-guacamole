import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Selects the displayed base plan again at checkout, independently of Play's
/// response order. Discounted offers require a separate disclosure contract.
ProductDetails? selectGooglePlayBasePlan(
  Iterable<ProductDetails> products, {
  required String productId,
  required String basePlanId,
  bool requireAndroidDetails = false,
}) {
  for (final product in products) {
    if (product.id != productId) continue;
    if (product is! GooglePlayProductDetails) {
      if (!requireAndroidDetails) return product;
      continue;
    }
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null ||
        offers == null ||
        index < 0 ||
        index >= offers.length) {
      continue;
    }
    final offer = offers[index];
    if (offer.basePlanId == basePlanId && offer.offerId == null) {
      return product;
    }
  }
  return null;
}
