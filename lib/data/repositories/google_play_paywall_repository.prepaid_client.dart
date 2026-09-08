part of 'google_play_paywall_repository.dart';

/// Internal license-test adapter using Flutter's public connection manager.
/// The ordinary platform addition does not expose prepaid configuration.
/// One connection is shared across account-scoped repositories; account
/// ownership and receipt verification remain in the repository above.
class PrepaidTestBillingClient implements BillingClient {
  PrepaidTestBillingClient({gp.BillingClientManager? manager})
    : _manager = manager ?? gp.BillingClientManager() {
    _ready = _configure();
    _ready.ignore();
  }

  static final PrepaidTestBillingClient shared = PrepaidTestBillingClient();
  final gp.BillingClientManager _manager;
  late final Future<void> _ready;

  Future<void> _configure() async {
    await _manager.runWithClientNonRetryable((_) async {});
    await enableGooglePlayPrepaidPending(_manager);
  }

  static IAPError _error(gp.BillingResultWrapper result) => IAPError(
    source: 'google_play',
    code: result.responseCode.name,
    message: result.debugMessage ?? '',
  );

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _manager.purchasesUpdatedStream.map((result) {
        final purchases = result.purchasesList
            .expand(GooglePlayPurchaseDetails.fromPurchase)
            .toList();
        if (result.billingResult.responseCode == gp.BillingResponse.ok) {
          return purchases;
        }
        final status =
            result.billingResult.responseCode == gp.BillingResponse.userCanceled
            ? PurchaseStatus.canceled
            : PurchaseStatus.error;
        if (purchases.isEmpty) {
          return [
            PurchaseDetails(
              productID: '',
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: '',
                source: 'google_play',
              ),
              transactionDate: null,
              status: status,
            )..error = _error(result.billingResult),
          ];
        }
        for (final purchase in purchases) {
          purchase.status = status;
          purchase.error = _error(result.billingResult);
        }
        return purchases;
      });

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    await _ready;
    final result = await _manager.runWithClient(
      (client) => client.queryProductDetails(
        productList: [
          for (final id in ids)
            gp.ProductWrapper(productId: id, productType: gp.ProductType.subs),
        ],
      ),
    );
    return ProductDetailsResponse(
      productDetails: result.productDetailsList
          .expand(GooglePlayProductDetails.fromProductDetails)
          .toList(),
      notFoundIDs: ids
          .difference(result.productDetailsList.map((p) => p.productId).toSet())
          .toList(),
      error: result.responseCode == gp.BillingResponse.ok
          ? null
          : _error(result.billingResult),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    await _ready;
    final product = purchaseParam.productDetails;
    if (product is! GooglePlayProductDetails ||
        product.subscriptionIndex == null) {
      throw StateError(
        'A verified Google Play subscription offer is required.',
      );
    }
    final offer = product
        .productDetails
        .subscriptionOfferDetails![product.subscriptionIndex!];
    final result = await _manager.runWithClientNonRetryable(
      (client) => client.launchBillingFlow(
        product: product.id,
        offerToken: offer.offerIdToken,
        accountId: purchaseParam.applicationUserName,
      ),
    );
    return result.responseCode == gp.BillingResponse.ok;
  }

  @override
  Future<List<PurchaseDetails>> restorePurchases({
    String? applicationUserName,
  }) async {
    await _ready;
    final result = await _manager.runWithClient(
      (client) => client.queryPurchases(gp.ProductType.subs),
    );
    // The wrapper's responseCode is force-OK for queries; use the actual result.
    if (result.billingResult.responseCode != gp.BillingResponse.ok) {
      throw StateError(
        'Google Play purchase query failed: ${result.billingResult.responseCode.name}',
      );
    }
    return result.purchasesList
        .expand(GooglePlayPurchaseDetails.fromPurchase)
        .toList();
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    await _ready;
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      throw StateError('Pending or failed purchases cannot be acknowledged.');
    }
    if (purchase is GooglePlayPurchaseDetails &&
        purchase.billingClientPurchase.isAcknowledged) {
      return;
    }
    final result = await _manager.runWithClient(
      (client) => client.acknowledgePurchase(
        purchase.verificationData.serverVerificationData,
      ),
    );
    if (result.responseCode != gp.BillingResponse.ok) {
      throw StateError('Google Play acknowledgement failed.');
    }
  }
}
