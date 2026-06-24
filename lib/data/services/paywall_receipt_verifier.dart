import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'operation_cancellation.dart';

typedef AccessTokenProvider = Future<String?> Function();
typedef SessionStatusProvider = bool Function();

class PaywallReceiptVerifier {
  PaywallReceiptVerifier({
    http.Client? client,
    String? endpoint,
    String? apiKey,
    AccessTokenProvider? tokenProvider,
    AccessTokenProvider? tokenRefresher,
    SessionStatusProvider? isSignedIn,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _endpoint =
           endpoint ??
           const String.fromEnvironment('CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT', defaultValue: ''),
       _apiKey = apiKey ?? const String.fromEnvironment('CHRONOSPARK_RECEIPT_VERIFY_KEY'),
       _tokenProvider = tokenProvider,
       _tokenRefresher = tokenRefresher,
       _isSignedIn = isSignedIn;

  final http.Client _client;
  final bool _ownsClient;
  final String _endpoint;
  final String _apiKey;
  final AccessTokenProvider? _tokenProvider;
  final AccessTokenProvider? _tokenRefresher;
  final SessionStatusProvider? _isSignedIn;
  String? _refreshedToken;
  bool _isDisposed = false;

  bool get isConfigured => _endpoint.trim().isNotEmpty;

  Future<bool> verifyPurchase(
    PurchaseDetails purchase, {
    CancellationToken? cancellationToken,
  }) async {
    if (!isConfigured) {
      return true;
    }

    cancellationToken.throwIfCancelled();
    if (_isDisposed || !_canVerifyForCurrentSession()) {
      return false;
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

    String? token = await _readToken(cancellationToken: cancellationToken);
    http.Response response = await _post(
      payload: payload,
      bearerToken: token,
      cancellationToken: cancellationToken,
    );

    if (response.statusCode == 401) {
      final bool refreshed = await _refreshToken(cancellationToken: cancellationToken);
      if (refreshed) {
        token = await _readToken(cancellationToken: cancellationToken);
        response = await _post(
          payload: payload,
          bearerToken: token,
          cancellationToken: cancellationToken,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    cancellationToken.throwIfCancelled();
    if (!_canVerifyForCurrentSession()) {
      return false;
    }

    final Map<String, dynamic> decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded['valid'] as bool?) ?? false;
  }

  bool _canVerifyForCurrentSession() => _isSignedIn?.call() ?? true;

  Future<String?> _readToken({CancellationToken? cancellationToken}) async {
    cancellationToken.throwIfCancelled();

    if (_refreshedToken != null && _refreshedToken!.trim().isNotEmpty) {
      return _refreshedToken!.trim();
    }

    if (_tokenProvider != null) {
      final String provided = (await _tokenProvider.call() ?? '').trim();
      cancellationToken.throwIfCancelled();
      if (provided.isNotEmpty) {
        return provided;
      }
    }

    final String key = _apiKey.trim();
    return key.isEmpty ? null : key;
  }

  Future<bool> _refreshToken({CancellationToken? cancellationToken}) async {
    if (_tokenRefresher == null) {
      return false;
    }

    cancellationToken.throwIfCancelled();
    final String refreshed = (await _tokenRefresher.call() ?? '').trim();
    cancellationToken.throwIfCancelled();
    if (refreshed.isEmpty) {
      return false;
    }

    _refreshedToken = refreshed;
    return true;
  }

  Future<http.Response> _post({
    required Map<String, dynamic> payload,
    required String? bearerToken,
    CancellationToken? cancellationToken,
  }) async {
    if (_isDisposed) {
      throw OperationCancelledException('Receipt verifier is disposed.');
    }
    cancellationToken.throwIfCancelled();
    if (!_canVerifyForCurrentSession()) {
      throw OperationCancelledException('Verification cancelled because user is signed out.');
    }

    final Map<String, String> headers = <String, String>{'Content-Type': 'application/json'};
    final String token = (bearerToken ?? '').trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = <String>['Bearer', token].join(' ');
    }

    final http.Response response = await _client.post(
      Uri.parse(_endpoint),
      headers: headers,
      body: jsonEncode(payload),
    );

    cancellationToken.throwIfCancelled();
    if (_isDisposed) {
      throw OperationCancelledException('Receipt verifier is disposed.');
    }
    if (!_canVerifyForCurrentSession()) {
      throw OperationCancelledException('Verification cancelled because user is signed out.');
    }
    return response;
  }

  void dispose() {
    _isDisposed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}
