import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'getAvailablePlans maps live Google Play prices when products resolve',
    () async {
      final _FakeBillingClient billing = _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: '4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>['chronospark_premium_annual'],
        ),
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
          );

      final plans = await repository.getAvailablePlans();

      expect(
        plans.firstWhere((plan) => plan.id == 'monthly').priceLabel,
        '4.99',
      );
      expect(
        plans.firstWhere((plan) => plan.id == 'monthly').isAvailable,
        isTrue,
      );
      expect(
        plans.firstWhere((plan) => plan.id == 'annual').isAvailable,
        isFalse,
      );

      repository.dispose();
    },
  );

  test(
    'purchase stream errors are tolerated without crashing repository',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _FakeBillingClient(
              purchaseStreamController: controller,
              productResponse: ProductDetailsResponse(
                productDetails: const <ProductDetails>[],
                notFoundIDs: const <String>[],
              ),
            ),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
          );

      await Logger.withMutedErrors(() async {
        controller.addError(Exception('stream failed'));
        await Future<void>.delayed(Duration.zero);
      });

      final SubscriptionState state = await repository
          .getUserSubscriptionState();
      expect(state.status, 'locked');

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'getAvailablePlans falls back to static plans when billing lookup throws',
    () async {
      final _FakeBillingClient billing = _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
        queryShouldThrow: true,
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
          );

      final plans = await Logger.withMutedErrors(
        () => repository.getAvailablePlans(),
      );

      expect(plans, hasLength(2));
      expect(
        plans.firstWhere((PaywallPlan plan) => plan.id == 'monthly').priceLabel,
        'from \$9.99 / month',
      );
      expect(
        plans.firstWhere((PaywallPlan plan) => plan.id == 'annual').priceLabel,
        'from \$89.99 / year',
      );

      repository.dispose();
    },
  );

  test('startSubscription throws for unknown plan id', () async {
    final _FakeBillingClient billing = _FakeBillingClient(
      productResponse: ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: billing,
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
    );

    await expectLater(
      () => repository.startSubscription('lifetime'),
      throwsA(isA<ArgumentError>()),
    );

    repository.dispose();
  });

  test(
    'startSubscription throws when product is missing in Google Play',
    () async {
      final _FakeBillingClient billing = _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>['chronospark_premium_monthly'],
        ),
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
          );

      await expectLater(
        () => repository.startSubscription('monthly'),
        throwsA(isA<StateError>()),
      );

      repository.dispose();
    },
  );

  test(
    'startSubscription resolves active state after verified purchase update',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: '4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>[],
        ),
        onBuyNonConsumable: (PurchaseParam param) async {
          final PurchaseDetails purchase = PurchaseDetails(
            purchaseID: 'purchase-1',
            productID: param.productDetails.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.purchased,
          )..pendingCompletePurchase = true;
          controller.add(<PurchaseDetails>[purchase]);
          return true;
        },
      );

      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            httpClient: MockClient((http.Request request) async {
              expect(
                request.url.toString(),
                'https://api.chronospark.app/verify',
              );
              expect(jsonDecode(request.body), <String, dynamic>{
                'productId': 'chronospark_premium_monthly',
                'purchaseToken': 'server-token',
                'purchaseType': 'subscription',
              });
              return http.Response('{"valid":true}', 200);
            }),
          );

      final SubscriptionState state = await repository.startSubscription(
        'monthly',
      );

      expect(state.isActive, isTrue);
      expect(state.status, 'active');
      expect(state.planId, 'monthly');
      expect(billing.completePurchaseCalls, 1);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'startSubscription returns verification_failed when receipt check fails',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: '4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>[],
        ),
        onBuyNonConsumable: (PurchaseParam param) async {
          final PurchaseDetails purchase = PurchaseDetails(
            purchaseID: 'purchase-2',
            productID: param.productDetails.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.purchased,
          )..pendingCompletePurchase = true;
          controller.add(<PurchaseDetails>[purchase]);
          return true;
        },
      );

      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            httpClient: MockClient((http.Request request) async {
              return http.Response('{"valid":false}', 200);
            }),
          );

      final SubscriptionState state = await repository.startSubscription(
        'monthly',
      );

      expect(state.isActive, isTrue);
      expect(state.status, 'pending_verification');
      expect(state.source, 'google_play_grace');
      expect(billing.completePurchaseCalls, 1);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'restorePurchases resolves restored state from purchase stream',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
        onRestorePurchases: () async {
          final PurchaseDetails purchase = PurchaseDetails(
            purchaseID: 'restore-1',
            productID: 'chronospark_premium_annual',
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.restored,
          )..pendingCompletePurchase = true;
          controller.add(<PurchaseDetails>[purchase]);
        },
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            httpClient: MockClient((http.Request request) async {
              return http.Response('{"valid":true}', 200);
            }),
          );

      final SubscriptionState state = await repository.restorePurchases();

      expect(state.status, 'restored');
      expect(state.planId, 'annual');
      expect(billing.restoreCalls, 1);
      expect(billing.completePurchaseCalls, 1);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'restorePurchases in testing mode unlocks using annual fallback',
    () async {
      final _FakeBillingClient billing = _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: true,
            sharedPreferencesLoader: SharedPreferences.getInstance,
          );

      final SubscriptionState state = await repository.restorePurchases();

      expect(state.isActive, isTrue);
      expect(state.status, 'unlocked_for_testing');
      expect(state.planId, 'annual');
      expect(state.isTesting, isTrue);
      expect(billing.restoreCalls, 0);

      repository.dispose();
    },
  );

  test(
    'purchase error completes pending subscription with error and completes purchase when pending',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: '4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>[],
        ),
        onBuyNonConsumable: (PurchaseParam param) async {
          final PurchaseDetails purchase =
              PurchaseDetails(
                  purchaseID: 'purchase-error',
                  productID: param.productDetails.id,
                  verificationData: PurchaseVerificationData(
                    localVerificationData: 'local-token',
                    serverVerificationData: 'server-token',
                    source: 'google_play',
                  ),
                  transactionDate: null,
                  status: PurchaseStatus.error,
                )
                ..pendingCompletePurchase = true
                ..error = IAPError(
                  source: 'google_play',
                  code: 'billing-unavailable',
                  message: 'Billing failed',
                );
          controller.add(<PurchaseDetails>[purchase]);
          return true;
        },
      );

      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            httpClient: MockClient((http.Request request) async {
              return http.Response('{"valid":true}', 200);
            }),
          );

      await Logger.withMutedErrors(
        () => expectLater(
          () => repository.startSubscription('monthly'),
          throwsA(isA<IAPError>()),
        ),
      );
      expect(billing.completePurchaseCalls, 1);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'restored purchase with unknown product id falls back to monthly plan id',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: 'USD 4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>[],
        ),
        onRestorePurchases: () async {
          final PurchaseDetails purchase = PurchaseDetails(
            purchaseID: 'purchase-unknown',
            productID: 'unexpected_product',
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.restored,
          )..pendingCompletePurchase = true;
          controller.add(<PurchaseDetails>[purchase]);
        },
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            httpClient: MockClient((http.Request request) async {
              return http.Response('{"valid":true}', 200);
            }),
          );

      final SubscriptionState state = await repository.restorePurchases();

      expect(state.planId, 'monthly');
      expect(state.isActive, isTrue);
      expect(state.status, 'restored');
      expect(billing.completePurchaseCalls, 1);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'missing receipt endpoint disables plans and blocks purchase/restore',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: 'USD 4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>[],
        ),
        onBuyNonConsumable: (PurchaseParam param) async {
          final PurchaseDetails purchase = PurchaseDetails(
            purchaseID: 'purchase-no-endpoint',
            productID: param.productDetails.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.purchased,
          )..pendingCompletePurchase = true;
          controller.add(<PurchaseDetails>[purchase]);
          return true;
        },
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: '   ',
          );

      final List<PaywallPlan> plans = await repository.getAvailablePlans();
      expect(
        plans.every((PaywallPlan plan) => plan.isAvailable == false),
        isTrue,
      );

      await expectLater(
        () => repository.startSubscription('monthly'),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        () => repository.restorePurchases(),
        throwsA(isA<StateError>()),
      );
      expect(billing.completePurchaseCalls, 0);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'receipt verification treats non-200 and invalid JSON as locked',
    () async {
      final StreamController<List<PurchaseDetails>> controller =
          StreamController<List<PurchaseDetails>>.broadcast();
      final List<int> statuses = <int>[];
      final _FakeBillingClient billing = _FakeBillingClient(
        purchaseStreamController: controller,
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[
            ProductDetails(
              id: 'chronospark_premium_monthly',
              title: 'Monthly',
              description: 'Monthly premium',
              price: 'USD 4.99',
              rawPrice: 4.99,
              currencyCode: 'USD',
            ),
          ],
          notFoundIDs: const <String>[],
        ),
        onBuyNonConsumable: (PurchaseParam param) async {
          final PurchaseDetails purchase = PurchaseDetails(
            purchaseID: 'purchase-http-fail-${statuses.length}',
            productID: param.productDetails.id,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.purchased,
          )..pendingCompletePurchase = true;
          controller.add(<PurchaseDetails>[purchase]);
          return true;
        },
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            httpClient: MockClient((http.Request request) async {
              statuses.add(statuses.length);
              if (statuses.length == 1) {
                return http.Response('{"valid":true}', 500);
              }
              return http.Response('not-json', 200);
            }),
          );

      final SubscriptionState first = await Logger.withMutedErrors(
        () => repository.startSubscription('monthly'),
      );
      final SubscriptionState second = await Logger.withMutedErrors(
        () => repository.startSubscription('monthly'),
      );

      expect(first.status, 'pending_verification');
      expect(second.status, 'pending_verification');
      expect(first.source, 'google_play_grace');
      expect(second.source, 'google_play_grace');
      expect(billing.completePurchaseCalls, 2);

      repository.dispose();
      await controller.close();
    },
  );

  test('cancelSubscription updates persisted user state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'paywall_subscription_state_v1': jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'monthly',
        'renewalDate': DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String(),
      }),
    });
    final _FakeBillingClient billing = _FakeBillingClient(
      productResponse: ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: billing,
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    final SubscriptionState state = await repository.cancelSubscription();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> persisted =
        jsonDecode(prefs.getString('paywall_subscription_state_v1')!)
            as Map<String, dynamic>;

    expect(state.status, 'cancelled');
    expect(state.isActive, isFalse);
    expect(persisted['status'], 'cancelled');
    expect(persisted['planId'], 'monthly');

    repository.dispose();
  });

  test('loads persisted active state and exposes entitlement', () async {
    final DateTime renewal = DateTime.now().add(const Duration(days: 2));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'paywall_subscription_state_v1': jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': renewal.toIso8601String(),
      }),
    });
    final _FakeBillingClient billing = _FakeBillingClient(
      productResponse: ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: billing,
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    final SubscriptionState state = await repository.getUserSubscriptionState();
    final entitlement = await repository.checkEntitlement(featureId: 'premium');

    expect(state.isActive, isTrue);
    expect(state.planId, 'annual');
    expect(entitlement.isEntitled, isTrue);
    expect(entitlement.expiresAt?.toIso8601String(), renewal.toIso8601String());

    repository.dispose();
  });

  test(
    'expired persisted state loads as locked while preserving renewal metadata',
    () async {
      final DateTime renewal = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues(<String, Object>{
        'paywall_subscription_state_v1': jsonEncode(<String, dynamic>{
          'isActive': true,
          'status': 'active',
          'planId': 'monthly',
          'renewalDate': renewal.toIso8601String(),
        }),
      });
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _FakeBillingClient(
              productResponse: ProductDetailsResponse(
                productDetails: const <ProductDetails>[],
                notFoundIDs: const <String>[],
              ),
            ),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
          );

      final SubscriptionState state = await repository
          .getUserSubscriptionState();
      final paywall = await repository.getPaywallConfig();

      expect(state.isActive, isFalse);
      expect(state.renewalDate?.toIso8601String(), renewal.toIso8601String());
      expect(paywall.isUnlocked, isFalse);

      repository.dispose();
    },
  );

  test('malformed persisted state falls back to locked defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'paywall_subscription_state_v1': '{not-json',
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
      ),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    final SubscriptionState state = await Logger.withMutedErrors(
      () => repository.getUserSubscriptionState(),
    );

    expect(state.isActive, isFalse);
    expect(state.status, 'locked');
    expect(state.planId, isNull);

    repository.dispose();
  });

  test('cancelSubscription survives persistence loader failures', () async {
    final GooglePlayPaywallRepository repository = await Logger.withMutedErrors(
      () async {
        return GooglePlayPaywallRepository(
          billingClient: _FakeBillingClient(
            productResponse: ProductDetailsResponse(
              productDetails: const <ProductDetails>[],
              notFoundIDs: const <String>[],
            ),
          ),
          paywallTestingModeOverride: false,
          sharedPreferencesLoader: () =>
              Future<SharedPreferences>.error(Exception('prefs failed')),
        );
      },
    );

    final SubscriptionState state = await Logger.withMutedErrors(
      () => repository.cancelSubscription(),
    );

    expect(state.status, 'cancelled');
    expect(state.isActive, isFalse);

    repository.dispose();
  });

  test('testing mode unlocks paywall without billing calls', () async {
    final _FakeBillingClient billing = _FakeBillingClient(
      productResponse: ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: billing,
      paywallTestingModeOverride: true,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    final paywall = await repository.getPaywallConfig();
    final entitlement = await repository.checkEntitlement(featureId: 'premium');
    final SubscriptionState state = await repository.startSubscription(
      'annual',
    );

    expect(paywall.isUnlocked, isTrue);
    expect(entitlement.isEntitled, isTrue);
    expect(state.isTesting, isTrue);
    expect(billing.queryProductCalls, 0);
    expect(billing.buyCalls, 0);

    repository.dispose();
  });
}

class _FakeBillingClient implements BillingClient {
  _FakeBillingClient({
    required this.productResponse,
    StreamController<List<PurchaseDetails>>? purchaseStreamController,
    this.onBuyNonConsumable,
    this.onRestorePurchases,
    this.queryShouldThrow = false,
  }) : _purchaseStreamController =
           purchaseStreamController ??
           StreamController<List<PurchaseDetails>>.broadcast();

  final ProductDetailsResponse productResponse;
  final StreamController<List<PurchaseDetails>> _purchaseStreamController;
  final Future<bool> Function(PurchaseParam param)? onBuyNonConsumable;
  final Future<void> Function()? onRestorePurchases;
  final bool queryShouldThrow;
  int queryProductCalls = 0;
  int buyCalls = 0;
  int restoreCalls = 0;
  int completePurchaseCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseStreamController.stream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls += 1;
    if (onBuyNonConsumable != null) {
      return onBuyNonConsumable!(purchaseParam);
    }
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completePurchaseCalls += 1;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queryProductCalls += 1;
    if (queryShouldThrow) {
      throw Exception('query failed');
    }
    return productResponse;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
    if (onRestorePurchases != null) {
      await onRestorePurchases!();
    }
  }
}
