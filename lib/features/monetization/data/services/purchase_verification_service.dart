import 'dart:convert';
import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/retry_executor.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum PurchaseVerificationMode { localTest, production }

enum PurchaseVerificationErrorCode {
  notConfigured,
  unauthenticated,
  networkUnavailable,
  invalidResponse,
  httpFailure,
}

class PurchaseVerificationRequest {
  const PurchaseVerificationRequest({
    required this.productId,
    required this.purchaseToken,
    required this.purchaseType,
  });

  final String productId;
  final String purchaseToken;
  final String purchaseType;

  bool get isValid =>
      productId.trim().isNotEmpty &&
      purchaseToken.trim().isNotEmpty &&
      (purchaseType == 'subscription' || purchaseType == 'inapp');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'purchaseToken': purchaseToken,
      'purchaseType': purchaseType,
    };
  }
}

class PurchaseVerificationResult {
  const PurchaseVerificationResult({
    required this.valid,
    this.error,
    this.errorCode,
    this.productId,
    this.planId,
    this.creditsGranted,
    this.orderId,
    this.expiryTimeMs,
  });

  final bool valid;
  final String? error;
  final PurchaseVerificationErrorCode? errorCode;
  final String? productId;
  final String? planId;
  final int? creditsGranted;
  final String? orderId;
  final int? expiryTimeMs;

  static PurchaseVerificationResult fromJson(Map<String, dynamic> body) {
    final bool valid = body['valid'] == true;
    return PurchaseVerificationResult(
      valid: valid,
      error: body['error']?.toString(),
      productId: body['productId']?.toString(),
      planId: body['planId']?.toString(),
      creditsGranted: (body['creditsGranted'] as num?)?.toInt(),
      orderId: body['orderId']?.toString(),
      expiryTimeMs: (body['expiryTimeMs'] as num?)?.toInt(),
      errorCode: valid ? null : PurchaseVerificationErrorCode.httpFailure,
    );
  }
}

class PurchaseVerificationService {
  PurchaseVerificationService({required this.httpClient, required this.mode});

  final http.Client httpClient;
  final PurchaseVerificationMode mode;

  Future<PurchaseVerificationResult> verifyPurchase({
    required String productId,
    required String purchaseToken,
    required String purchaseType,
  }) async {
    final PurchaseVerificationRequest request = PurchaseVerificationRequest(
      productId: productId,
      purchaseToken: purchaseToken,
      purchaseType: purchaseType,
    );
    if (!request.isValid) {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'Invalid purchase verification payload.',
        errorCode: PurchaseVerificationErrorCode.invalidResponse,
      );
    }

    if (mode == PurchaseVerificationMode.localTest) {
      return PurchaseVerificationResult(
        valid: true,
        productId: productId,
        planId: purchaseType == 'subscription' ? 'local_test' : null,
        creditsGranted: purchaseType == 'inapp' ? 1 : null,
      );
    }

    final Uri? endpoint = parseSecureHttpsEndpoint(Env.receiptVerifyEndpoint);
    if (endpoint == null) {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'Receipt verification endpoint is not configured.',
        errorCode: PurchaseVerificationErrorCode.notConfigured,
      );
    }

    final String? accessToken = currentSupabaseAccessToken();
    if (accessToken == null) {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'User must be authenticated to verify purchases.',
        errorCode: PurchaseVerificationErrorCode.unauthenticated,
      );
    }

    final http.Response response;
    try {
      response = await runWithRetry<http.Response>(
        maxAttempts: 3,
        action: () async {
          final http.Response next = await httpClient
              .post(
                endpoint,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
                body: jsonEncode(request.toJson()),
              )
              .timeout(const Duration(seconds: 20));
          if (next.statusCode == 408 ||
              next.statusCode == 429 ||
              next.statusCode >= 500) {
            throw http.ClientException(
              'Transient receipt verification failure: ${next.statusCode}',
              endpoint,
            );
          }
          return next;
        },
        retryIf: (Object error) {
          return error is TimeoutException || error is http.ClientException;
        },
      );
    } on Object {
      return const PurchaseVerificationResult(
        valid: false,
        error:
            'Verification temporarily unavailable due to network conditions. Please retry.',
        errorCode: PurchaseVerificationErrorCode.networkUnavailable,
      );
    }

    if (response.statusCode != 200) {
      return PurchaseVerificationResult(
        valid: false,
        error: 'Verification failed with status ${response.statusCode}.',
        errorCode: PurchaseVerificationErrorCode.httpFailure,
      );
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on Object {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'Verification response could not be parsed.',
        errorCode: PurchaseVerificationErrorCode.invalidResponse,
      );
    }
    if (decodedBody is! Map<String, dynamic>) {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'Verification response payload is invalid.',
        errorCode: PurchaseVerificationErrorCode.invalidResponse,
      );
    }
    return PurchaseVerificationResult.fromJson(decodedBody);
  }
}

PurchaseVerificationMode resolvePurchaseVerificationMode() {
  return resolvePurchaseVerificationModeFromFlags(
    isReleaseMode: kReleaseMode,
    isProduction: Env.isProduction,
    isPaywallDisabled: Env.isPaywallDisabled,
  );
}

PurchaseVerificationMode resolvePurchaseVerificationModeFromFlags({
  required bool isReleaseMode,
  required bool isProduction,
  required bool isPaywallDisabled,
}) {
  // Never allow local receipt verification in release binaries.
  if (isReleaseMode) {
    return PurchaseVerificationMode.production;
  }
  final bool allowLocalVerification = !isProduction && isPaywallDisabled;
  return allowLocalVerification
      ? PurchaseVerificationMode.localTest
      : PurchaseVerificationMode.production;
}
