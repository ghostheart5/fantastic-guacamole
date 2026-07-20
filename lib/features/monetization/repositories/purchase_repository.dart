import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:fantastic_guacamole/features/monetization/domain/purchase_operation_result.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_package.dart';
import 'package:fantastic_guacamole/features/monetization/models/ai_credit_wallet.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_plan.dart';
import 'package:fantastic_guacamole/features/monetization/models/subscription_status.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/ai_credit_repository.dart';
import 'package:fantastic_guacamole/features/monetization/repositories/subscription_repository.dart';
import 'package:fantastic_guacamole/features/monetization/services/billing_service.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

abstract class PurchaseRepository {
  Future<PurchaseOperationResult> startSubscriptionPurchase(
    SubscriptionPlan plan,
  );
  Future<PurchaseOperationResult> startCreditPurchase(AiCreditPackage pack);
  Future<PurchaseOperationResult> restorePurchases();
  void dispose();
}

class GooglePlayPurchaseRepository implements PurchaseRepository {
  GooglePlayPurchaseRepository(
    this._billingService,
    this._subscriptionRepository,
    this._aiCreditRepository, {
    http.Client? httpClient,
  }) : 
       _httpClient = httpClient ?? http.Client() {
    _subscription = _billingService.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        Logger.error('Monetization purchase stream error', error);
      },
    );
  }

  final BillingService _billingService;
  final SubscriptionRepository _subscriptionRepository;
  final AiCreditRepository _aiCreditRepository;
  final http.Client _httpClient;

  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  final Map<String, Completer<PurchaseOperationResult>> _pending =
      <String, Completer<PurchaseOperationResult>>{};

  @override
  void dispose() {
    _subscription.cancel();
  }

  @override
  Future<PurchaseOperationResult> restorePurchases() async {
    final Completer<PurchaseOperationResult> completer =
        Completer<PurchaseOperationResult>();
    _pending['__restore__'] = completer;
    await _billingService.restorePurchases();
    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => const PurchaseOperationResult(
        success: false,
        message: 'No restorable purchases were found.',
        productId: '__restore__',
        restored: true,
      ),
    );
  }

  @override
  Future<PurchaseOperationResult> startCreditPurchase(
    AiCreditPackage pack,
  ) async {
    final ProductDetails product = await _loadProductDetails(pack.productId);
    final Completer<PurchaseOperationResult> completer =
        Completer<PurchaseOperationResult>();
    _pending[pack.productId] = completer;
    final bool launched = await _billingService.buyConsumable(product: product);
    if (!launched) {
      _pending.remove(pack.productId);
      return PurchaseOperationResult(
        success: false,
        message: 'Google Play did not launch the credit purchase flow.',
        productId: pack.productId,
      );
    }
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(pack.productId);
        return PurchaseOperationResult(
          success: false,
          message: 'Credit purchase timed out.',
          productId: pack.productId,
        );
      },
    );
  }

  @override
  Future<PurchaseOperationResult> startSubscriptionPurchase(
    SubscriptionPlan plan,
  ) async {
    final String productId = plan.productId ??
        (throw ArgumentError('Plan ${plan.id} is not purchasable.'));
    final ProductDetails product = await _loadProductDetails(productId);
    final Completer<PurchaseOperationResult> completer =
        Completer<PurchaseOperationResult>();
    _pending[productId] = completer;
    final bool launched = await _billingService.buyNonConsumable(product: product);
    if (!launched) {
      _pending.remove(productId);
      return PurchaseOperationResult(
        success: false,
        message: 'Google Play did not launch the purchase flow.',
        productId: productId,
      );
    }
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(productId);
        return PurchaseOperationResult(
          success: false,
          message: 'Subscription purchase timed out.',
          productId: productId,
        );
      },
    );
  }

  Future<ProductDetails> _loadProductDetails(String productId) async {
    final ProductDetailsResponse response = await _billingService
        .queryProductDetails(<String>{productId});
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    if (response.productDetails.isEmpty) {
      throw StateError('Google Play product $productId was not found.');
    }
    return response.productDetails.first;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        final PurchaseOperationResult result = PurchaseOperationResult(
          success: false,
          message: purchase.error?.message ?? 'Purchase failed.',
          productId: purchase.productID,
        );
        _completePending(purchase.productID, result);
        if (purchase.pendingCompletePurchase) {
          await _billingService.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final PurchaseOperationResult result = await _verifyPurchase(purchase);
        _completePending(purchase.productID, result);
        if (purchase.status == PurchaseStatus.restored) {
          _completePending('__restore__', result);
        }
        if (purchase.pendingCompletePurchase) {
          await _billingService.completePurchase(purchase);
        }
      }
    }
  }

  void _completePending(String key, PurchaseOperationResult result) {
    final Completer<PurchaseOperationResult>? completer = _pending.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  Future<PurchaseOperationResult> _verifyPurchase(
    PurchaseDetails purchase,
  ) async {
    final Uri? endpoint = parseSecureHttpsEndpoint(Env.receiptVerifyEndpoint);
    if (endpoint == null) {
      return PurchaseOperationResult(
        success: false,
        message: 'Receipt verification endpoint is not configured.',
        productId: purchase.productID,
      );
    }
    final String? accessToken = currentSupabaseAccessToken();
    if (accessToken == null) {
      return PurchaseOperationResult(
        success: false,
        message: 'You must be signed in before completing purchases.',
        productId: purchase.productID,
      );
    }

    final bool isSubscription = purchase.productID == 'chronospark_premium_monthly' ||
        purchase.productID == 'chronospark_premium_annual';
    final http.Response response = await _httpClient.post(
      endpoint,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(<String, dynamic>{
        'productId': purchase.productID,
        'purchaseToken': purchase.verificationData.serverVerificationData,
        'purchaseType': isSubscription ? 'subscription' : 'inapp',
      }),
    );

    if (response.statusCode != 200) {
      Logger.error('Purchase verification failed HTTP ${response.statusCode}');
      return PurchaseOperationResult(
        success: false,
        message: 'Purchase verification failed. Please retry.',
        productId: purchase.productID,
      );
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on Object {
      return PurchaseOperationResult(
        success: false,
        message: 'Purchase verification response was unreadable.',
        productId: purchase.productID,
      );
    }
    if (decodedBody is! Map<String, dynamic>) {
      return PurchaseOperationResult(
        success: false,
        message: 'Purchase verification returned an invalid payload.',
        productId: purchase.productID,
      );
    }
    final Map<String, dynamic> body = decodedBody;
    if (body['valid'] != true) {
      return PurchaseOperationResult(
        success: false,
        message: body['error']?.toString() ?? 'Purchase could not be verified.',
        productId: purchase.productID,
      );
    }

    final SubscriptionStatus subscriptionStatus =
        await _subscriptionRepository.getSubscriptionStatus();
    final AiCreditWallet wallet = await _aiCreditRepository.getWallet();

    if (isSubscription) {
      AppAnalytics.track(
        purchase.status == PurchaseStatus.restored
            ? 'subscription_renewed'
            : 'subscription_started',
        params: <String, Object?>{
          'product_id': purchase.productID,
          'status': subscriptionStatus.status,
        },
      );
      return PurchaseOperationResult(
        success: true,
        message: 'Premium entitlement refreshed.',
        productId: purchase.productID,
        restored: purchase.status == PurchaseStatus.restored,
        subscriptionStatus: subscriptionStatus,
        wallet: wallet,
      );
    }

    AppAnalytics.track(
      'credit_pack_purchased',
      params: <String, Object?>{
        'product_id': purchase.productID,
        'credits_balance': wallet.balance,
      },
    );
    return PurchaseOperationResult(
      success: true,
      message: 'Credits added to your wallet.',
      productId: purchase.productID,
      wallet: wallet,
    );
  }
}