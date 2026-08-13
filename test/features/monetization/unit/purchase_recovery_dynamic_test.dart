import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/monetization/data/repositories/purchase_repository.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/purchase_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const String _journalKey = 'monetization_pending_purchase_journal_v1';

void main() {
  group('GooglePlayPurchaseRepository recovery', () {
    test(
      'no pending purchases completes without grant or journal mutation',
      () async {
        final _Harness harness = await _Harness.create();

        await harness.repository.recoverPendingPurchases();

        expect(harness.verifier.calls, 0);
        expect(harness.billing.finalizations, isEmpty);
        expect(harness.backend.writes, isEmpty);
        await harness.dispose();
      },
    );

    test(
      'valid recovery verifies, persists, finalizes, and removes journal',
      () async {
        final _Harness harness = await _Harness.create(
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-1'),
          ],
        );
        await harness.seed('chronospark_credits_100');
        harness.backend.events.clear();

        await harness.repository.recoverPendingPurchases();
        await _settle();

        expect(harness.verifier.calls, 1);
        expect(harness.billing.finalizations, hasLength(1));
        expect(harness.backend.events, <String>['write', 'finalize', 'write']);
        expect(
          await harness.store.readString(_journalKey),
          contains('"entries":[]'),
        );
        await harness.dispose();
      },
    );

    test('repeated recovery finalizes a purchase only once', () async {
      final _Harness harness = await _Harness.create(
        pending: <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ],
      );
      await harness.seed('chronospark_credits_100');

      await harness.repository.recoverPendingPurchases();
      await _settle();
      await harness.repository.recoverPendingPurchases();
      await _settle();

      expect(harness.verifier.calls, 1);
      expect(harness.billing.finalizations, hasLength(1));
      await harness.dispose();
    });

    test(
      'duplicate remote result model finalizes without a second grant',
      () async {
        final _Harness harness = await _Harness.create(
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-1'),
          ],
          verifierResults: <PurchaseVerificationResult>[
            const PurchaseVerificationResult(
              valid: true,
              productId: 'chronospark_credits_100',
              creditsGranted: 0,
            ),
          ],
        );
        await harness.seed('chronospark_credits_100');

        await harness.repository.recoverPendingPurchases();
        await _settle();

        expect(harness.billing.finalizations, hasLength(1));
        expect(harness.verifier.calls, 1);
        await harness.dispose();
      },
    );

    test(
      'wrong user cannot verify or finalize another users journal entry',
      () async {
        final _Harness harness = await _Harness.create(
          activeUserId: 'user-b',
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-a'),
          ],
        );
        await harness.seed('chronospark_credits_100', userId: 'user-a');

        await harness.repository.recoverPendingPurchases();
        await _settle();

        expect(harness.verifier.calls, 0);
        expect(harness.billing.finalizations, isEmpty);
        expect(await harness.store.readString(_journalKey), contains('user-a'));
        await harness.dispose();
      },
    );

    test('malformed purchase token cannot verify or finalize', () async {
      final _Harness harness = await _Harness.create(
        pending: <PurchaseDetails>[_purchase('chronospark_credits_100', '')],
      );
      await harness.seed('chronospark_credits_100');

      await harness.repository.recoverPendingPurchases();
      await _settle();

      expect(harness.verifier.calls, 0);
      expect(harness.billing.finalizations, isEmpty);
      await harness.dispose();
    });

    test(
      'journal round trip restarts and preserves a retryable entry',
      () async {
        final _Harness first = await _Harness.create(
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-1'),
          ],
          verifierResults: <PurchaseVerificationResult>[
            const PurchaseVerificationResult(valid: false),
          ],
        );
        await first.seed('chronospark_credits_100');
        await first.repository.recoverPendingPurchases();
        await _settle();
        expect(
          await first.store.readString(_journalKey),
          contains('chronospark_credits_100'),
        );
        await first.dispose();

        final _Harness restarted = await _Harness.create(
          backend: first.backend,
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-1'),
          ],
        );
        await _settle();
        expect(restarted.billing.finalizations, hasLength(1));
        await restarted.dispose();
      },
    );

    test('retry after recoverable failure grants once after restart', () async {
      final _Harness first = await _Harness.create(
        pending: <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ],
        verifierResults: <PurchaseVerificationResult>[
          const PurchaseVerificationResult(valid: false),
        ],
      );
      await first.seed('chronospark_credits_100');
      await first.repository.recoverPendingPurchases();
      await _settle();
      await first.dispose();

      final _Harness retry = await _Harness.create(
        backend: first.backend,
        pending: <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ],
      );
      await _settle();
      expect(retry.billing.finalizations, hasLength(1));
      await retry.dispose();
    });

    test(
      'one invalid purchase does not poison a later valid recovery',
      () async {
        final _Harness harness = await _Harness.create(
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'bad'),
            _purchase('chronospark_credits_500', 'good'),
          ],
          verifierResults: <PurchaseVerificationResult>[
            const PurchaseVerificationResult(valid: false),
            const PurchaseVerificationResult(
              valid: true,
              productId: 'chronospark_credits_500',
            ),
          ],
        );
        await harness.seed('chronospark_credits_100');
        await harness.seed('chronospark_credits_500');

        await harness.repository.recoverPendingPurchases();
        await _settle();

        expect(
          harness.billing.finalizations.single.productID,
          'chronospark_credits_500',
        );
        expect(
          await harness.store.readString(_journalKey),
          contains('chronospark_credits_100'),
        );
        await harness.dispose();
      },
    );

    test(
      'crash after remote grant is safe on restart with duplicate model',
      () async {
        final _Harness harness = await _Harness.create();
        harness.billing.pending = <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ];
        await harness.seed(
          'chronospark_credits_100',
          verified: true,
          token: 'token-1',
        );

        await harness.repository.recoverPendingPurchases();
        await _settle();

        expect(harness.verifier.calls, 0);
        expect(harness.billing.finalizations, hasLength(1));
        await harness.dispose();
      },
    );

    test(
      'lost response retry is safe when restarted verification reports applied',
      () async {
        final _Harness first = await _Harness.create(
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-1'),
          ],
          verifierResults: <PurchaseVerificationResult>[
            const PurchaseVerificationResult(valid: false),
          ],
        );
        await first.seed('chronospark_credits_100');
        await first.repository.recoverPendingPurchases();
        await _settle();
        await first.dispose();
        final _Harness retry = await _Harness.create(
          backend: first.backend,
          pending: <PurchaseDetails>[
            _purchase('chronospark_credits_100', 'token-1'),
          ],
        );
        await _settle();
        expect(retry.billing.finalizations, hasLength(1));
        await retry.dispose();
      },
    );

    test(
      'crash before consume continues from persisted verified state',
      () async {
        final _Harness harness = await _Harness.create();
        harness.billing.pending = <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ];
        await harness.seed(
          'chronospark_credits_100',
          verified: true,
          token: 'token-1',
        );
        await harness.repository.recoverPendingPurchases();
        await _settle();
        expect(harness.billing.finalizations, hasLength(1));
        await harness.dispose();
      },
    );

    test(
      'post-consume pre-removal replay remains a safe finalization',
      () async {
        final _Harness harness = await _Harness.create();
        harness.billing.pending = <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ];
        await harness.seed(
          'chronospark_credits_100',
          verified: true,
          token: 'token-1',
        );
        await harness.repository.recoverPendingPurchases();
        await _settle();
        expect(
          await harness.store.readString(_journalKey),
          contains('"entries":[]'),
        );
        await harness.dispose();
      },
    );

    test(
      'completed purchase replay is a no-op after journal finalization',
      () async {
        final _Harness harness = await _Harness.create();
        await harness.repository.recoverPendingPurchases();
        expect(harness.billing.finalizations, isEmpty);
        await harness.dispose();
      },
    );

    test('cross-user switch cannot recover prior user purchase', () async {
      final _Harness harness = await _Harness.create(activeUserId: 'user-b');
      await harness.seed('chronospark_credits_100', userId: 'user-a');
      harness.billing.pending = <PurchaseDetails>[
        _purchase('chronospark_credits_100', 'token-a'),
      ];
      await harness.repository.recoverPendingPurchases();
      await _settle();
      expect(harness.billing.finalizations, isEmpty);
      await harness.dispose();
    });

    test(
      'a throwing recovery gateway does not poison a later independent recovery',
      () async {
        final _Harness harness = await _Harness.create();
        await harness.seed('chronospark_credits_100');
        harness.billing.throwOnRecover = true;
        await harness.repository.recoverPendingPurchases();
        harness.billing.throwOnRecover = false;
        harness.billing.pending = <PurchaseDetails>[
          _purchase('chronospark_credits_100', 'token-1'),
        ];
        await harness.repository.recoverPendingPurchases();
        await _settle();
        expect(harness.billing.finalizations, hasLength(1));
        await harness.dispose();
      },
    );
  });
}

class _Harness {
  _Harness._(this.backend, this.billing, this.verifier, this._activeUserId) {
    _rebuild();
  }

  final _MemoryBackend backend;
  final _FakeBilling billing;
  final _FakeVerifier verifier;
  final String _activeUserId;
  late GooglePlayPurchaseRepository repository;

  SecureStore get store => SecureStore(backend: backend);

  static Future<_Harness> create({
    _MemoryBackend? backend,
    List<PurchaseDetails> pending = const <PurchaseDetails>[],
    List<PurchaseVerificationResult>? verifierResults,
    String activeUserId = 'user-a',
  }) async {
    final _MemoryBackend selectedBackend = backend ?? _MemoryBackend();
    final _FakeBilling billing = _FakeBilling(pending, selectedBackend.events);
    final _FakeVerifier verifier = _FakeVerifier(verifierResults);
    final _Harness harness = _Harness._(
      selectedBackend,
      billing,
      verifier,
      activeUserId,
    );
    await _settle();
    return harness;
  }

  Future<void> seed(
    String productId, {
    String userId = 'user-a',
    bool verified = false,
    String? token,
  }) async {
    await repository.dispose();
    final List<PurchaseDetails> deferredPending = billing.pending;
    billing.pending = verified ? deferredPending : const <PurchaseDetails>[];
    final String? existingPayload = await store.readString(_journalKey);
    final Map<String, dynamic> existing = existingPayload == null
        ? <String, dynamic>{}
        : jsonDecode(existingPayload) as Map<String, dynamic>;
    final List<Map<String, dynamic>> entries =
        ((existing['entries'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic entry) => Map<String, dynamic>.from(entry as Map))
            .where(
              (Map<String, dynamic> entry) => entry['product_id'] != productId,
            )
            .toList();
    entries.add(<String, dynamic>{
      'product_id': productId,
      'purchase_type': 'inapp',
      'user_id': userId,
      'is_consumable': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'server_verified': verified,
      'purchase_token_hash': verified ? _hash(token ?? '') : null,
      'checkout_launched': true,
    });
    await store.writeString(
      _journalKey,
      jsonEncode(<String, Object>{'version': 1, 'entries': entries}),
    );
    _rebuild();
    await _settle();
    billing.pending = deferredPending;
  }

  Future<void> dispose() => repository.dispose();

  void _rebuild() {
    repository = GooglePlayPurchaseRepository(
      billingGateway: billing,
      verificationService: verifier,
      journalStore: store,
      recoveryCooldown: Duration.zero,
      authContextLoader: () => PurchaseAuthContext(
        userId: _activeUserId,
        accessToken: 'token-$_activeUserId',
      ),
    );
  }
}

class _MemoryBackend implements SecureStoreBackend {
  final Map<String, String> _values = <String, String>{};
  final List<String> events = <String>[];
  final List<String> writes = <String>[];

  @override
  Future<void> delete({required String key}) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    events.add('write');
    writes.add(value);
    _values[key] = value;
  }
}

class _FakeBilling implements PurchaseRecoveryBillingGateway {
  _FakeBilling(this.pending, this._events);

  List<PurchaseDetails> pending;
  final List<String> _events;
  bool throwOnRecover = false;
  final List<PurchaseDetails> finalizations = <PurchaseDetails>[];
  final StreamController<List<PurchaseDetails>> _stream =
      StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _stream.stream;

  @override
  Future<bool> buyConsumable(PurchaseParam param) async => false;

  @override
  Future<bool> buyNonConsumable(PurchaseParam param) async => false;

  @override
  Future<void> finalizePurchase(
    PurchaseDetails purchase, {
    required bool isConsumable,
  }) async {
    _events.add('finalize');
    finalizations.add(purchase);
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> productIds,
  ) async {
    return ProductDetailsResponse(
      productDetails: const <ProductDetails>[],
      notFoundIDs: productIds.toList(),
    );
  }

  @override
  Future<List<PurchaseDetails>?> recoverPendingPurchases() async {
    if (throwOnRecover) {
      throw StateError('simulated recovery transport failure');
    }
    return pending;
  }

  @override
  Future<void> restorePurchases() async {}
}

class _FakeVerifier implements PurchaseVerifier {
  _FakeVerifier(List<PurchaseVerificationResult>? results)
    : _results = Queue<PurchaseVerificationResult>.of(
        results ??
            <PurchaseVerificationResult>[
              const PurchaseVerificationResult(valid: true),
            ],
      );

  final Queue<PurchaseVerificationResult> _results;
  int calls = 0;

  @override
  Future<PurchaseVerificationResult> verifyPurchase({
    required String productId,
    required String purchaseToken,
    required String purchaseType,
    required String accessToken,
  }) async {
    calls++;
    return _results.isEmpty
        ? const PurchaseVerificationResult(valid: true)
        : _results.removeFirst();
  }
}

PurchaseDetails _purchase(String productId, String token) {
  return PurchaseDetails(
    purchaseID: 'purchase-$token',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: token,
      serverVerificationData: token,
      source: 'test',
    ),
    transactionDate: '1',
    status: PurchaseStatus.purchased,
  );
}

String _hash(String token) => sha256.convert(utf8.encode(token)).toString();

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
