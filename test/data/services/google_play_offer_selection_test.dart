import 'package:fantastic_guacamole/data/services/google_play_offer_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  const id = 'chronospark_premium_monthly';
  SubscriptionOfferDetailsWrapper offer(String basePlan, {String? offerId}) {
    return SubscriptionOfferDetailsWrapper(
      basePlanId: basePlan,
      offerId: offerId,
      offerTags: const [],
      offerIdToken: '$basePlan-${offerId ?? 'base'}',
      pricingPhases: const [
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: 'P1M',
          formattedPrice: r'$4.99',
          priceAmountMicros: 4990000,
          priceCurrencyCode: 'USD',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        ),
      ],
    );
  }

  final products = GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: 'Test catalog',
      name: 'Premium',
      productId: id,
      productType: ProductType.subs,
      title: 'Premium',
      subscriptionOfferDetails: [
        offer('monthly-prepaid-test'),
        offer('monthly', offerId: 'intro'),
        offer('monthly'),
      ],
    ),
  );

  test('monthly selects its base plan after prepaid and discounted offers', () {
    expect(
      selectGooglePlayBasePlan(products, productId: id, basePlanId: 'monthly'),
      same(products[2]),
    );
  });
  test('prepaid selection is explicit and independent of response order', () {
    expect(
      selectGooglePlayBasePlan(
        products.reversed,
        productId: id,
        basePlanId: 'monthly-prepaid-test',
        requireAndroidDetails: true,
      ),
      same(products[0]),
    );
  });
  test('missing base plan does not fall back to a different offer', () {
    expect(
      selectGooglePlayBasePlan(
        products.take(2),
        productId: id,
        basePlanId: 'monthly',
      ),
      isNull,
    );
  });
  test('a different product cannot satisfy the requested plan', () {
    expect(
      selectGooglePlayBasePlan(
        products,
        productId: 'another-product',
        basePlanId: 'monthly',
      ),
      isNull,
    );
  });
}
