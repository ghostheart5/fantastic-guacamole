import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

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

  Future<bool> verifyPurchase(PurchaseDetails purchase) async {
    if (!isConfigured) {
      return false;
    }

    try {
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
        String authorization = 'Bearer ';
        authorization += _apiKey;
        headers['Authorization'] = authorization;
      }

      final http.Response response = await _client.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return (decoded['valid'] as bool?) ?? false;
    } catch (error, stackTrace) {
      developer.log(
        'Receipt verification failed.',
        name: 'PaywallReceiptVerifier',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
