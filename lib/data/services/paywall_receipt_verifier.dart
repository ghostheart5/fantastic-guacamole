import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/system/subscription_product_ids.dart';
import '../../core/system/subscription_model.dart';

class ReceiptVerificationResult {
  const ReceiptVerificationResult({
    required this.isValid,
    this.plan,
    this.billingCycle,
  });

  const ReceiptVerificationResult.invalid()
    : isValid = false,
      plan = null,
      billingCycle = null;

  final bool isValid;
  final SubscriptionPlan? plan;
  final BillingCycle? billingCycle;
}

class PaywallReceiptVerifier {
  PaywallReceiptVerifier({http.Client? client, String? endpoint, String? apiKey})
    : _client = client ?? http.Client(),
      _endpoint =
          endpoint ??
          const String.fromEnvironment('CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT', defaultValue: ''),
      _apiKey = apiKey ?? const String.fromEnvironment('CHRONOSPARK_RECEIPT_VERIFY_KEY');

  final http.Client _client;
  final String _endpoint;
  final String _apiKey;

  bool get isConfigured => _endpoint.trim().isNotEmpty;

  Future<ReceiptVerificationResult> verifyPurchase(PurchaseDetails purchase) async {
    if (!isConfigured) {
      return _resultFor(productId: purchase.productID);
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'transactionDate': purchase.transactionDate,
      'status': purchase.status.name,
      'verificationData': <String, dynamic>{
        'source': purchase.verificationData.source,
        'localVerificationData': purchase.verificationData.localVerificationData,
        'serverVerificationData': purchase.verificationData.serverVerificationData,
      },
    };

    final Map<String, String> headers = <String, String>{'Content-Type': 'application/json'};
    if (_apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }

    final http.Response response = await _client.post(
      Uri.parse(_endpoint),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const ReceiptVerificationResult.invalid();
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final bool isValid = (decoded['valid'] as bool?) ?? false;
    if (!isValid) {
      return const ReceiptVerificationResult.invalid();
    }

    final String decodedProductId = (decoded['productId'] as String?)?.trim() ?? '';
    return _resultFor(
      productId: decodedProductId.isNotEmpty ? decodedProductId : purchase.productID,
      entitlement: (decoded['entitlement'] as String?)?.trim(),
    );
  }

  ReceiptVerificationResult _resultFor({required String productId, String? entitlement}) {
    final SubscriptionPlan? plan =
        _planFromEntitlement(entitlement) ?? _planFromProductId(productId);
    final BillingCycle? billingCycle = _billingCycleFromProductId(productId);
    if (plan == null || plan == SubscriptionPlan.base || billingCycle == null) {
      return const ReceiptVerificationResult.invalid();
    }

    return ReceiptVerificationResult(
      isValid: true,
      plan: plan,
      billingCycle: billingCycle,
    );
  }

  SubscriptionPlan? _planFromEntitlement(String? entitlement) {
    switch (entitlement?.toLowerCase()) {
      case 'premium':
        return SubscriptionPlan.premium;
      case 'ultimate':
        return SubscriptionPlan.ultimate;
      case 'base':
        return SubscriptionPlan.base;
      default:
        return null;
    }
  }

  SubscriptionPlan? _planFromProductId(String productId) {
    switch (productId) {
      case SubscriptionProductIds.premiumMonthly:
      case SubscriptionProductIds.premiumYearly:
        return SubscriptionPlan.premium;
      default:
        return null;
    }
  }

  BillingCycle? _billingCycleFromProductId(String productId) {
    switch (productId) {
      case SubscriptionProductIds.premiumYearly:
        return BillingCycle.yearly;
      case SubscriptionProductIds.premiumMonthly:
        return BillingCycle.monthly;
      default:
        return null;
    }
  }
}
