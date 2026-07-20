import 'dart:convert';
import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/retry_executor.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum PurchaseVerificationMode { localTest, production }

class PurchaseVerificationResult {
  const PurchaseVerificationResult({
    required this.valid,
    this.error,
    this.productId,
    this.planId,
    this.creditsGranted,
    this.orderId,
    this.expiryTimeMs,
  });

  final bool valid;
  final String? error;
  final String? productId;
  final String? planId;
  final int? creditsGranted;
  final String? orderId;
  final int? expiryTimeMs;
}

class PurchaseVerificationService {
  PurchaseVerificationService({
    required this.httpClient,
    required this.mode,
  });

  final http.Client httpClient;
  final PurchaseVerificationMode mode;

  Future<PurchaseVerificationResult> verifyPurchase({
    required String productId,
    required String purchaseToken,
    required String purchaseType,
  }) async {
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
      );
    }

    final String? accessToken = currentSupabaseAccessToken();
    if (accessToken == null) {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'User must be authenticated to verify purchases.',
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
                body: jsonEncode(<String, dynamic>{
                  'productId': productId,
                  'purchaseToken': purchaseToken,
                  'purchaseType': purchaseType,
                }),
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
      );
    }

    if (response.statusCode != 200) {
      return PurchaseVerificationResult(
        valid: false,
        error: 'Verification failed with status ${response.statusCode}.',
      );
    }

    final dynamic decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on Object {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'Verification response could not be parsed.',
      );
    }
    if (decodedBody is! Map<String, dynamic>) {
      return const PurchaseVerificationResult(
        valid: false,
        error: 'Verification response payload is invalid.',
      );
    }
    final Map<String, dynamic> body = decodedBody;
    return PurchaseVerificationResult(
      valid: body['valid'] == true,
      error: body['error']?.toString(),
      productId: body['productId']?.toString(),
      planId: body['planId']?.toString(),
      creditsGranted: (body['creditsGranted'] as num?)?.toInt(),
      orderId: body['orderId']?.toString(),
      expiryTimeMs: (body['expiryTimeMs'] as num?)?.toInt(),
    );
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
