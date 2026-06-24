import 'dart:convert';
import 'dart:io';

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
      return true;
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

    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_endpoint),
        headers: headers,
        body: jsonEncode(payload),
      );
    } on IOException catch (e) {
      throw Exception('Receipt verification unavailable: no network connection. ($e)');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded['valid'] as bool?) ?? false;
  }
}
