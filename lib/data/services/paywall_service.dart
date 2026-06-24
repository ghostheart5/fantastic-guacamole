import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _premiumKey = 'paywall_premium_v1';

  static const Set<String> productIds = <String>{
    'chronospark_premium_monthly',
    'chronospark_premium_yearly',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final PaywallReceiptVerifier _verifier;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initialize({
    required void Function(bool isPremium) onPremiumChanged,
    void Function(String message)? onError,
  }) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      onPremiumChanged(await readCachedPremium());
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen((List<PurchaseDetails> purchases) async {
      for (final PurchaseDetails purchase in purchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          bool verified = false;
          try {
            verified = await _verifier.verifyPurchase(purchase);
          } catch (_) {
            onError?.call('Your purchase was completed but could not be verified right now due to a network issue. Please restore purchases once connectivity is available.');
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            continue;
          }
          if (verified) {
            await _setPremium(true);
            onPremiumChanged(true);
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
    });

    onPremiumChanged(await readCachedPremium());
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

  Future<bool> readCachedPremium() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<void> _setPremium(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, value);
  }

  Future<void> dispose() async {
    await _purchaseSub?.cancel();
  }
}
