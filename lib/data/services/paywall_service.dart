import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'operation_cancellation.dart';
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
  PaywallService({PaywallReceiptVerifier? verifier, SessionStatusProvider? isSignedIn})
    : _verifier =
          verifier ??
          PaywallReceiptVerifier(
            isSignedIn: isSignedIn ?? (() => FirebaseAuth.instance.currentUser != null),
          );

  static const String _premiumKey = 'paywall_premium_v1';

  static const Set<String> productIds = <String>{
    'chronospark_premium_monthly',
    'chronospark_premium_yearly',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final PaywallReceiptVerifier _verifier;
  final CancellationTokenSource _disposeSource = CancellationTokenSource();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> initialize({
    required void Function(bool isPremium) onPremiumChanged,
    void Function(String message)? onError,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();

    final bool available = await _iap.isAvailable();
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();

    if (!available) {
      onPremiumChanged(await readCachedPremium(cancellationToken: cancellationToken));
      return;
    }

    _purchaseSub = _iap.purchaseStream.listen((List<PurchaseDetails> purchases) async {
      if (_disposeSource.isCancelled) {
        return;
      }

      for (final PurchaseDetails purchase in purchases) {
        if (_disposeSource.isCancelled) {
          return;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          try {
            final bool verified = await _verifier.verifyPurchase(
              purchase,
              cancellationToken: _disposeSource.token,
            );
            if (verified) {
              await _setPremium(true, cancellationToken: _disposeSource.token);
              onPremiumChanged(true);
            } else {
              onError?.call('Purchase verification failed. Premium access not granted.');
            }
          } on OperationCancelledException {
            return;
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

    onPremiumChanged(await readCachedPremium(cancellationToken: cancellationToken));
  }

  Future<List<PaywallProduct>> queryProducts({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();

    final bool available = await _iap.isAvailable();
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
    if (!available) {
      return const <PaywallProduct>[];
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
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

  Future<void> buyProduct(String productId, {CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();

    final bool available = await _iap.isAvailable();
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
    if (!available) {
      throw Exception('Store is currently unavailable on this device.');
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(<String>{productId});
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
    if (response.productDetails.isEmpty) {
      throw Exception('Selected product not found in store configuration.');
    }

    final ProductDetails product = response.productDetails.first;
    final PurchaseParam param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
  }

  Future<void> restorePurchases({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
    await _iap.restorePurchases();
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
  }

  Future<bool> readCachedPremium({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
    return prefs.getBool(_premiumKey) ?? false;
  }

  Future<void> _setPremium(bool value, {CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
    await prefs.setBool(_premiumKey, value);
    cancellationToken.throwIfCancelled();
    _disposeSource.token.throwIfCancelled();
  }

  Future<void> dispose() async {
    _disposeSource.cancel();
    await _purchaseSub?.cancel();
    _verifier.dispose();
  }
}
