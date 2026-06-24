import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/system/subscription_product_ids.dart';
import '../../core/system/subscription_model.dart';
import 'paywall_receipt_verifier.dart';

class PaywallProduct {
  const PaywallProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final String price;
}

class PaywallService {
  PaywallService({PaywallReceiptVerifier? verifier})
    : _verifier = verifier ?? PaywallReceiptVerifier();

  static const Set<String> productIds = <String>{
    SubscriptionProductIds.premiumMonthly,
    SubscriptionProductIds.premiumYearly,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final PaywallReceiptVerifier _verifier;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initialize({
    required void Function(SubscriptionSnapshot subscription) onSubscriptionChanged,
    void Function(String message)? onError,
  }) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      onSubscriptionChanged(SubscriptionSnapshot.base());
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen((List<PurchaseDetails> purchases) async {
      SubscriptionSnapshot? highestSubscription;
      for (final PurchaseDetails purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final ReceiptVerificationResult verification = await _verifier.verifyPurchase(purchase);
          if (verification.isValid && verification.plan != null) {
            final SubscriptionSnapshot verifiedSubscription = _buildSubscriptionSnapshot(
              purchase: purchase,
              plan: verification.plan!,
              billingCycle: verification.billingCycle ?? BillingCycle.monthly,
            );
            highestSubscription = _pickHigherSubscription(highestSubscription, verifiedSubscription);
          } else {
            onError?.call('Purchase verification failed. Premium access not granted.');
          }
        }
        if (purchase.status == PurchaseStatus.error) {
          onError?.call(purchase.error?.message ?? 'Purchase failed.');
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }

      if (highestSubscription != null) {
        onSubscriptionChanged(highestSubscription);
      }
    });

    await restorePurchases();
  }

  Future<List<PaywallProduct>> queryProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      return const <PaywallProduct>[];
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      return const <PaywallProduct>[];
    }

    return response.productDetails
        .map(
          (ProductDetails p) =>
              PaywallProduct(id: p.id, title: p.title, description: p.description, price: p.price),
        )
        .toList();
  }

  Future<void> buyProduct(String productId) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      throw Exception('Store is currently unavailable on this device.');
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(<String>{productId});
    if (response.productDetails.isEmpty) {
      throw Exception('Selected product not found in store configuration.');
    }

    final ProductDetails product = response.productDetails.first;
    final PurchaseParam param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
  }

  SubscriptionSnapshot _buildSubscriptionSnapshot({
    required PurchaseDetails purchase,
    required SubscriptionPlan plan,
    required BillingCycle billingCycle,
  }) {
    final DateTime startDate = _parseTransactionDate(purchase.transactionDate);
    return SubscriptionSnapshot(
      plan: plan,
      billingCycle: billingCycle,
      status: SubscriptionStatus.active,
      subscriptionStartDate: startDate,
      mockNextBillingDate: startDate.add(Duration(days: billingCycle.billingIntervalDays)),
    );
  }

  SubscriptionSnapshot _pickHigherSubscription(
    SubscriptionSnapshot? current,
    SubscriptionSnapshot candidate,
  ) {
    if (current == null) {
      return candidate;
    }

    return candidate.plan.index > current.plan.index ? candidate : current;
  }

  DateTime _parseTransactionDate(String? rawValue) {
    final String raw = rawValue?.trim() ?? '';
    if (raw.isEmpty) {
      return DateTime.now();
    }

    final int? millis = int.tryParse(raw);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    return DateTime.tryParse(raw) ?? DateTime.now();
  }
}
