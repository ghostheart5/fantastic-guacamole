import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:chronospark/data/services/paywall_receipt_verifier.dart';

// Replays a fixed sequence of responses/exceptions.
class _SequenceClient extends http.BaseClient {
  _SequenceClient(this._steps);

  final List<Object> _steps;
  int _index = 0;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    final Object step = _steps[_index++];
    if (step is Exception) throw step;
    if (step is http.Response) {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode(step.body)),
        step.statusCode,
        headers: step.headers,
        request: request,
      );
    }
    throw StateError('Unsupported step: $step');
  }
}

PurchaseDetails _purchase({String productId = 'chronospark_premium_monthly'}) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'play_store',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: PurchaseStatus.purchased,
  );
}

void main() {
  group('PaywallReceiptVerifier', () {
    group('configuration guard', () {
      test('fails closed when receipt endpoint is not configured', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([]),
          endpoint: '',
        );
        expect(await verifier.verifyPurchase(_purchase()), isFalse);
      });

      test('isConfigured is false for blank endpoint', () {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([]),
          endpoint: '   ',
        );
        expect(verifier.isConfigured, isFalse);
      });
    });

    group('successful verification', () {
      test('returns true when server responds valid:true', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([http.Response('{"valid":true}', 200)]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isTrue);
      });

      test('returns false when server responds valid:false', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([http.Response('{"valid":false}', 200)]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isFalse);
      });
    });

    group('error handling', () {
      test('returns false on 4xx (non-transient) without retry', () async {
        final client = _SequenceClient([http.Response('{"error":"unauthorized"}', 401)]);
        final verifier = PaywallReceiptVerifier(
          client: client,
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isFalse);
        expect(client._index, 1); // exactly one attempt
      });

      test('returns false on malformed JSON body', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([http.Response('not-json', 200)]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isFalse);
      });

      test('returns false when JSON body is not an object', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([http.Response('[true]', 200)]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isFalse);
      });

      test('returns false when valid field is missing', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([http.Response('{"status":"ok"}', 200)]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isFalse);
      });
    });

    group('retry behaviour', () {
      test('retries transient SocketException then succeeds', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([
            SocketException('offline'),
            http.Response('{"valid":true}', 200),
          ]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isTrue);
      });

      test('retries 429 response then succeeds', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([
            http.Response('', 429),
            http.Response('{"valid":true}', 200),
          ]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isTrue);
      });

      test('retries 500 response then succeeds', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([
            http.Response('', 500),
            http.Response('{"valid":true}', 200),
          ]),
          endpoint: 'https://example.com/verify',
        );
        expect(await verifier.verifyPurchase(_purchase()), isTrue);
      });

      test('exhausts all retries and throws when every attempt is a transient failure', () async {
        final verifier = PaywallReceiptVerifier(
          client: _SequenceClient([
            SocketException('offline'),
            SocketException('offline'),
            SocketException('offline'),
          ]),
          endpoint: 'https://example.com/verify',
        );
        expect(() => verifier.verifyPurchase(_purchase()), throwsA(isA<SocketException>()));
      });
    });

    group('request headers', () {
      test('sends Authorization header when API key is provided', () async {
        final client = _SequenceClient([http.Response('{"valid":true}', 200)]);
        final verifier = PaywallReceiptVerifier(
          client: client,
          endpoint: 'https://example.com/verify',
          apiKey: 'secret-key',
          enableCertificatePinning: false,
        );
        await verifier.verifyPurchase(_purchase());
        final sentRequest = client.lastRequest!;
        expect(sentRequest.headers['Authorization'], 'Bearer secret-key');
      });

      test('omits Authorization header when API key is empty', () async {
        final client = _SequenceClient([http.Response('{"valid":true}', 200)]);
        final verifier = PaywallReceiptVerifier(
          client: client,
          endpoint: 'https://example.com/verify',
          apiKey: '',
          enableCertificatePinning: false,
        );
        await verifier.verifyPurchase(_purchase());
        expect(client.lastRequest!.headers.containsKey('Authorization'), isFalse);
      });
    });
  });
}
