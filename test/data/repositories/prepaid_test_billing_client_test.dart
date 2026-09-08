import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/data/services/google_play_pending_compat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart' as gp;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeClient native;
  late gp.BillingClientManager manager;
  late PrepaidTestBillingClient adapter;
  setUp(() {
    manager = gp.BillingClientManager(
      billingClientFactory: (listener, alternative) {
        native = _NativeClient(listener);
        return native;
      },
    );
    adapter = PrepaidTestBillingClient(manager: manager);
  });
  tearDown(() => manager.dispose());

  test(
    'checkout forwards the selected prepaid offer and account binding',
    () async {
      final product = GooglePlayProductDetails.fromProductDetails(
        const gp.ProductDetailsWrapper(
          description: 'Synthetic prepaid test',
          name: 'Premium',
          productId: 'chronospark_premium_monthly',
          productType: gp.ProductType.subs,
          title: 'Premium',
          subscriptionOfferDetails: [
            gp.SubscriptionOfferDetailsWrapper(
              basePlanId: 'monthly-prepaid-test',
              offerTags: [],
              offerIdToken: 'synthetic-prepaid-offer',
              pricingPhases: [
                gp.PricingPhaseWrapper(
                  billingCycleCount: 1,
                  billingPeriod: 'P1M',
                  formattedPrice: r'$4.99',
                  priceAmountMicros: 4990000,
                  priceCurrencyCode: 'USD',
                  recurrenceMode: gp.RecurrenceMode.nonRecurring,
                ),
              ],
            ),
          ],
        ),
      ).single;
      expect(
        await adapter.buyNonConsumable(
          purchaseParam: PurchaseParam(
            productDetails: product,
            applicationUserName: 'synthetic-account-fingerprint',
          ),
        ),
        isTrue,
      );
      expect(native.launchedProduct, product.id);
      expect(native.launchedOffer, 'synthetic-prepaid-offer');
      expect(native.launchedAccount, 'synthetic-account-fingerprint');
      expect(native.acknowledgements, 0);
    },
  );

  test('completed purchase acknowledgement failures are surfaced', () async {
    final purchase = PurchaseDetails(
      productID: 'chronospark_premium_monthly',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: 'synthetic-completed',
        source: 'google_play',
      ),
      transactionDate: '1',
      status: PurchaseStatus.purchased,
    );
    native.ackResult = gp.BillingResponse.error;
    await expectLater(adapter.completePurchase(purchase), throwsStateError);
    native.ackResult = gp.BillingResponse.ok;
    await adapter.completePurchase(purchase);
    expect(native.acknowledgements, 2);
  });

  test(
    'prepaid pending support is enabled after the initial connection',
    () async {
      expect(await adapter.restorePurchases(), isEmpty);
      expect(native.prepaidConfigurations, [false, true]);
    },
  );
  test(
    'restore rejects the actual query error despite force-OK wrapper status',
    () async {
      native.queryResult = const gp.PurchasesResultWrapper(
        responseCode: gp.BillingResponse.ok,
        billingResult: gp.BillingResultWrapper(
          responseCode: gp.BillingResponse.error,
        ),
        purchasesList: [],
      );
      await expectLater(adapter.restorePurchases(), throwsStateError);
    },
  );
  test(
    'empty canceled callbacks remain canceled and never acknowledge',
    () async {
      final result = adapter.purchaseStream.first;
      native.listener(
        const gp.PurchasesResultWrapper(
          responseCode: gp.BillingResponse.userCanceled,
          billingResult: gp.BillingResultWrapper(
            responseCode: gp.BillingResponse.userCanceled,
          ),
          purchasesList: [],
        ),
      );
      final purchase = (await result).single;
      expect(purchase.status, PurchaseStatus.canceled);
      expect(purchase.productID, isEmpty);
      await expectLater(adapter.completePurchase(purchase), throwsStateError);
      expect(native.acknowledgements, 0);
    },
  );
  test('pending purchases remain pending until Google changes state', () async {
    native.queryResult = const gp.PurchasesResultWrapper(
      responseCode: gp.BillingResponse.ok,
      billingResult: gp.BillingResultWrapper(
        responseCode: gp.BillingResponse.ok,
      ),
      purchasesList: [
        gp.PurchaseWrapper(
          orderId: '',
          packageName: 'com.ghostheart5.chronospark',
          purchaseTime: 1,
          purchaseToken: 'synthetic-pending',
          signature: '',
          products: ['chronospark_premium_monthly'],
          isAutoRenewing: false,
          originalJson: '{}',
          isAcknowledged: false,
          purchaseState: gp.PurchaseStateWrapper.pending,
        ),
      ],
    );
    final purchase = (await adapter.restorePurchases()).single;
    expect(purchase.status, PurchaseStatus.pending);
    await expectLater(adapter.completePurchase(purchase), throwsStateError);
    expect(native.acknowledgements, 0);
  });
}

class _NativeClient extends gp.BillingClient {
  _NativeClient(this.listener) : super(listener, null);
  final gp.PurchasesUpdatedListener listener;
  final List<bool> prepaidConfigurations = [];
  int acknowledgements = 0;
  gp.BillingResponse ackResult = gp.BillingResponse.ok;
  String? launchedProduct;
  String? launchedOffer;
  String? launchedAccount;
  @override
  Future<gp.BillingResultWrapper> launchBillingFlow({
    required String product,
    String? offerToken,
    String? accountId,
    String? obfuscatedProfileId,
    String? oldProduct,
    String? purchaseToken,
    gp.ReplacementMode? replacementMode,
  }) async {
    launchedProduct = product;
    launchedOffer = offerToken;
    launchedAccount = accountId;
    return const gp.BillingResultWrapper(responseCode: gp.BillingResponse.ok);
  }

  gp.PurchasesResultWrapper queryResult = const gp.PurchasesResultWrapper(
    responseCode: gp.BillingResponse.ok,
    billingResult: gp.BillingResultWrapper(responseCode: gp.BillingResponse.ok),
    purchasesList: [],
  );
  @override
  Future<gp.BillingResultWrapper> startConnection({
    required gp.OnBillingServiceDisconnected onBillingServiceDisconnected,
    gp.BillingChoiceMode billingChoiceMode =
        gp.BillingChoiceMode.playBillingOnly,
    GooglePlayPendingParams? pendingPurchasesParams,
  }) async {
    prepaidConfigurations.add(
      pendingPurchasesParams?.enablePrepaidPlans ?? false,
    );
    return const gp.BillingResultWrapper(responseCode: gp.BillingResponse.ok);
  }

  @override
  Future<void> endConnection() async {}
  @override
  Future<gp.PurchasesResultWrapper> queryPurchases(
    gp.ProductType productType,
  ) async => queryResult;
  @override
  Future<gp.BillingResultWrapper> acknowledgePurchase(
    String purchaseToken,
  ) async {
    acknowledgements++;
    return gp.BillingResultWrapper(responseCode: ackResult);
  }
}
