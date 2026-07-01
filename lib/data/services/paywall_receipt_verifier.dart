import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/utils/retry.dart';
import '../../core/security/certificate_pinning_service.dart';
import 'package:http/io_client.dart';

class PaywallReceiptVerifier {
  PaywallReceiptVerifier({
    http.Client? client,
    String? endpoint,
    String? apiKey,
    bool enableCertificatePinning = true,
  })
    : _client = client ?? _createHttpClientWithPinning(enableCertificatePinning),
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

    final Uri endpoint = Uri.parse(_endpoint);
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

    final http.Response response = await retry<http.Response>(
      () async {
        final http.Response response = await _client
            .post(
              endpoint,
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 429 || response.statusCode >= 500) {
          throw http.ClientException(
            'Transient verification failure (${response.statusCode})',
            endpoint,
          );
        }

        return response;
      },
      maxAttempts: 3,
      shouldRetry: (Object error, StackTrace stackTrace) =>
          error is TimeoutException || error is SocketException || error is http.ClientException,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final Object decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return false;
    }
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    return decoded['valid'] == true;
  }

  /// Create HTTP client with certificate pinning for ChronoSpark API
  static http.Client _createHttpClientWithPinning(bool enablePinning) {
    if (!enablePinning) {
      return http.Client();
    }

    try {
        final pinnedClient = CertificatePinningService.createPinnedHttpClient(
          certHash: CertificatePinningService.chronosparkApiCertHash,
        );
        return IOClient(pinnedClient);
    } catch (e) {
      // Fallback to non-pinned client if pinning fails
      return http.Client();
    }
  }
}
