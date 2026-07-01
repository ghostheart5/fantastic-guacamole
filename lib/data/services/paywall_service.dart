import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/system/subscription_model.dart';
import 'paywall_receipt_verifier.dart';
import 'secure_entitlement_store.dart';

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
  PaywallService({
    PaywallReceiptVerifier? verifier,
    EntitlementStore? entitlementStore,
    InAppPurchase? iap,
  }) : _verifier = verifier ?? PaywallReceiptVerifier(),
       _entitlementStore = entitlementStore ?? SecureEntitlementStore(),
       _iap = iap ?? InAppPurchase.instance;

  static const Set<String> productIds = <String>{
    'chronospark_premium_monthly',
    'chronospark_premium_yearly',
  };

  final InAppPurchase _iap;
  final PaywallReceiptVerifier _verifier;
  final EntitlementStore _entitlementStore;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool get _supportsInAppPurchase =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<bool> _isStoreAvailable() async {
    if (!_supportsInAppPurchase) {
      return false;
    }

    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize({
    required void Function(SubscriptionSnapshot? subscription) onSubscriptionChanged,
    void Function(String message)? onError,
  }) async {
    onSubscriptionChanged(await readVerifiedSubscription());

    final bool available = await _isStoreAvailable();
    if (!available) {
      return;
    }

    await _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final PurchaseDetails purchase in purchases) {
          try {
            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              final bool verified = await _verifier.verifyPurchase(purchase);
              if (verified) {
                final SubscriptionSnapshot snapshot = _snapshotForPurchase(purchase);
                await storeVerifiedSubscription(snapshot);
                onSubscriptionChanged(snapshot);
              } else {
                await clearVerifiedSubscription();
                onSubscriptionChanged(null);
                onError?.call('Purchase verification failed. Premium access not granted.');
              }
            }

            if (purchase.status == PurchaseStatus.error) {
              onError?.call(purchase.error?.message ?? 'Purchase failed.');
            }
          } catch (error) {
            onError?.call('Purchase processing failed: $error');
          } finally {
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        onError?.call('Purchase stream failed: $error');
      },
    );
  }

  Future<SubscriptionSnapshot?> readVerifiedSubscription() async {
    return _entitlementStore.readSubscription();
  }

  Future<void> storeVerifiedSubscription(SubscriptionSnapshot subscription) async {
    if (!subscription.isValid) {
      await clearVerifiedSubscription();
      return;
    }

    await _entitlementStore.writeSubscription(subscription);
  }

  Future<void> clearVerifiedSubscription() async {
    await _entitlementStore.clearSubscription();
  }

  Future<List<PaywallProduct>> queryProducts() async {
    final bool available = await _isStoreAvailable();
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
    final bool available = await _isStoreAvailable();
    if (!available) {
      throw StateError('Store is currently unavailable on this device.');
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(<String>{productId});
    if (response.productDetails.isEmpty) {
      throw StateError('Selected product not found in store configuration.');
    }

    final ProductDetails product = response.productDetails.first;
    final PurchaseParam param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    if (!await _isStoreAvailable()) {
      return;
    }
    await _iap.restorePurchases();
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
  }

  SubscriptionSnapshot _snapshotForPurchase(PurchaseDetails purchase) {
    final BillingCycle cycle = purchase.productID.endsWith('_yearly')
        ? BillingCycle.yearly
        : BillingCycle.monthly;
    final DateTime now = DateTime.now();
    return SubscriptionSnapshot(
      plan: SubscriptionPlan.premium,
      billingCycle: cycle,
      status: SubscriptionStatus.active,
      subscriptionStartDate: now,
      mockNextBillingDate: now.add(Duration(days: cycle.billingIntervalDays)),
    );
  }
}
