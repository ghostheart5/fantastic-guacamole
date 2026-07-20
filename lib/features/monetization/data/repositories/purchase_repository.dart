import 'dart:async';

import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/purchase_verification_service.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseResult {
  const PurchaseResult({
    required this.success,
    required this.productId,
    this.message,
    this.verifiedPlanId,
    this.creditsGranted,
  });

  final bool success;
  final String productId;
  final String? message;
  final String? verifiedPlanId;
  final int? creditsGranted;
}

abstract class PurchaseRepository {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan);
  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack);
  Future<PurchaseResult> restorePurchases();
}

class GooglePlayPurchaseRepository implements PurchaseRepository {
  GooglePlayPurchaseRepository(this._iap, this._verificationService);

  final InAppPurchase _iap;
  final PurchaseVerificationService _verificationService;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) async {
    AppAnalytics.track(MonetizationEvents.subscriptionPurchaseStarted);
    final ProductDetailsResponse productResponse =
        await _iap.queryProductDetails(<String>{plan.productId});
    if (productResponse.productDetails.isEmpty) {
      return PurchaseResult(
        success: false,
        productId: plan.productId,
        message: 'Google Play product not found for ${plan.productId}.',
      );
    }

    final PurchaseParam param =
        PurchaseParam(productDetails: productResponse.productDetails.first);
    final bool launched = await _iap.buyNonConsumable(purchaseParam: param);
    if (!launched) {
      AppAnalytics.track(MonetizationEvents.subscriptionPurchaseFailed);
      return PurchaseResult(
        success: false,
        productId: plan.productId,
        message: 'Google Play purchase flow did not launch.',
      );
    }

    return _waitForVerification(plan.productId, 'subscription');
  }

  @override
  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack) async {
    AppAnalytics.track(MonetizationEvents.creditPurchaseStarted);
    final ProductDetailsResponse productResponse =
        await _iap.queryProductDetails(<String>{pack.productId});
    if (productResponse.productDetails.isEmpty) {
      return PurchaseResult(
        success: false,
        productId: pack.productId,
        message: 'Google Play product not found for ${pack.productId}.',
      );
    }

    final PurchaseParam param =
        PurchaseParam(productDetails: productResponse.productDetails.first);
    final bool launched =
        await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    if (!launched) {
      AppAnalytics.track(MonetizationEvents.creditPurchaseFailed);
      return PurchaseResult(
        success: false,
        productId: pack.productId,
        message: 'Google Play purchase flow did not launch.',
      );
    }

    return _waitForVerification(pack.productId, 'inapp');
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    await _iap.restorePurchases();
    return const PurchaseResult(
      success: true,
      productId: '__restore__',
      message: 'Restore requested from Google Play.',
    );
  }

  Future<PurchaseResult> _waitForVerification(
    String expectedProductId,
    String purchaseType,
  ) async {
    final Completer<PurchaseResult> completer = Completer<PurchaseResult>();

    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _iap.purchaseStream.listen((List<PurchaseDetails> updates) async {
      for (final PurchaseDetails purchase in updates) {
        if (purchase.productID != expectedProductId) {
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          AppAnalytics.track(
            purchaseType == 'subscription'
                ? MonetizationEvents.subscriptionPurchaseFailed
                : MonetizationEvents.creditPurchaseFailed,
          );
          if (!completer.isCompleted) {
            completer.complete(PurchaseResult(
              success: false,
              productId: purchase.productID,
              message: purchase.error?.message ?? 'Purchase failed.',
            ));
          }
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final PurchaseVerificationResult verify =
              await _verificationService.verifyPurchase(
            productId: purchase.productID,
            purchaseToken: purchase.verificationData.serverVerificationData,
            purchaseType: purchaseType,
          );

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          if (!completer.isCompleted) {
            completer.complete(PurchaseResult(
              success: verify.valid,
              productId: purchase.productID,
              message: verify.error,
              verifiedPlanId: verify.planId,
              creditsGranted: verify.creditsGranted,
            ));
          }

          AppAnalytics.track(
            verify.valid
                ? (purchaseType == 'subscription'
                    ? MonetizationEvents.subscriptionPurchaseVerified
                    : MonetizationEvents.creditPurchaseVerified)
                : (purchaseType == 'subscription'
                    ? MonetizationEvents.subscriptionPurchaseFailed
                    : MonetizationEvents.creditPurchaseFailed),
          );
        }
      }
    });

    try {
      return await completer.future.timeout(const Duration(minutes: 2));
    } finally {
      await subscription.cancel();
    }
  }
}
