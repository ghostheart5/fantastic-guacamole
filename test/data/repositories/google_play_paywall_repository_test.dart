import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/repositories/google_play_paywall_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    hide BillingClient;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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

  test('getAvailablePlans never advertises a Google Play free trial', () async {
    const PricingPhaseWrapper paidPhase = PricingPhaseWrapper(
      billingCycleCount: 0,
      billingPeriod: 'P1M',
      formattedPrice: r'$9.99',
      priceAmountMicros: 9990000,
      priceCurrencyCode: 'USD',
      recurrenceMode: RecurrenceMode.infiniteRecurring,
    );
    const PricingPhaseWrapper invalidCycle = PricingPhaseWrapper(
      billingCycleCount: 0,
      billingPeriod: 'P1W',
      formattedPrice: r'$0.00',
      priceAmountMicros: 0,
      priceCurrencyCode: 'USD',
      recurrenceMode: RecurrenceMode.finiteRecurring,
    );
    const PricingPhaseWrapper invalidPeriod = PricingPhaseWrapper(
      billingCycleCount: 1,
      billingPeriod: 'not-a-period',
      formattedPrice: r'$0.00',
      priceAmountMicros: 0,
      priceCurrencyCode: 'USD',
      recurrenceMode: RecurrenceMode.finiteRecurring,
    );
    const PricingPhaseWrapper longestTrial = PricingPhaseWrapper(
      billingCycleCount: 1,
      billingPeriod: 'P1Y2M3W4D',
      formattedPrice: r'$0.00',
      priceAmountMicros: 0,
      priceCurrencyCode: 'USD',
      recurrenceMode: RecurrenceMode.finiteRecurring,
    );
    const ProductDetailsWrapper wrapper = ProductDetailsWrapper(
      description: 'Premium access',
      name: 'ChronoSpark Premium',
      productId: 'chronospark_premium_monthly',
      productType: ProductType.subs,
      title: 'ChronoSpark Premium',
      subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'monthly',
          offerTags: <String>[],
          offerIdToken: 'offer-token',
          pricingPhases: <PricingPhaseWrapper>[
            paidPhase,
            invalidCycle,
            invalidPeriod,
            longestTrial,
          ],
        ),
      ],
    );
    final GooglePlayProductDetails details =
        GooglePlayProductDetails.fromProductDetails(wrapper).single;
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: <ProductDetails>[details],
          notFoundIDs: const <String>['chronospark_premium_annual'],
        ),
      ),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
    );

    final List<PaywallPlan> plans = await repository.getAvailablePlans();
    final PaywallPlan monthly = plans.firstWhere(
      (PaywallPlan plan) => plan.id == 'monthly',
    );

    expect(monthly.freeTrialDays, 0);
    expect(
      monthly.benefits.where(
        (String benefit) => benefit.toLowerCase().contains('free trial'),
      ),
      isEmpty,
    );

    repository.dispose();
  });

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
      final DateTime verifiedExpiry = DateTime.now().toUtc().add(
        const Duration(days: 17),
      );
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
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
            secureStore: secureStore,
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
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'valid': true,
                  'productId': 'chronospark_premium_monthly',
                  'status': 'active',
                  'expiryTimeMs': verifiedExpiry.millisecondsSinceEpoch,
                }),
                200,
              );
            }),
          );

      final SubscriptionState state = await repository.startSubscription(
        'monthly',
      );

      expect(state.isActive, isTrue);
      expect(state.status, 'active');
      expect(state.planId, 'monthly');
      expect(
        state.renewalDate?.millisecondsSinceEpoch,
        verifiedExpiry.millisecondsSinceEpoch,
      );
      expect(billing.completePurchaseCalls, 1);

      final Map<String, dynamic> persisted =
          jsonDecode(
                (await secureStore.readString(
                  'paywall_subscription_state_v1',
                ))!,
              )
              as Map<String, dynamic>;
      expect(persisted['expirySource'], 'google_play_server');
      expect(
        DateTime.parse(
          persisted['renewalDate'] as String,
        ).millisecondsSinceEpoch,
        verifiedExpiry.millisecondsSinceEpoch,
      );

      final GooglePlayPaywallRepository restoredRepository =
          GooglePlayPaywallRepository(
            billingClient: billing,
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
            secureStore: secureStore,
          );
      final SubscriptionState restored = await restoredRepository
          .getUserSubscriptionState();
      expect(restored.isActive, isTrue);
      expect(
        restored.renewalDate?.millisecondsSinceEpoch,
        verifiedExpiry.millisecondsSinceEpoch,
      );

      repository.dispose();
      restoredRepository.dispose();
      await controller.close();
    },
  );

  test(
    'startSubscription rejects missing or implausible server expiry',
    () async {
      for (final DateTime? invalidExpiry in <DateTime?>[
        null,
        DateTime.now().toUtc().add(const Duration(days: 401)),
      ]) {
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
                return http.Response(
                  jsonEncode(<String, dynamic>{
                    'valid': true,
                    'productId': 'chronospark_premium_monthly',
                    'status': 'active',
                    if (invalidExpiry != null)
                      'expiryTimeMs': invalidExpiry.millisecondsSinceEpoch,
                  }),
                  200,
                );
              }),
            );

        final SubscriptionState state = await repository.startSubscription(
          'monthly',
        );

        expect(state.isActive, isFalse);
        expect(state.status, 'verification_failed');
        expect(billing.completePurchaseCalls, 1);

        repository.dispose();
        await controller.close();
      }
    },
  );

  test(
    'restorePurchases resolves restored state from purchase stream',
    () async {
      final DateTime verifiedExpiry = DateTime.now().toUtc().add(
        const Duration(days: 73),
      );
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
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'valid': true,
                  'productId': 'chronospark_premium_annual',
                  'status': 'grace',
                  'expiryTimeMs': verifiedExpiry.millisecondsSinceEpoch,
                }),
                200,
              );
            }),
          );

      final List<SubscriptionState> states = await Future.wait(
        <Future<SubscriptionState>>[
          repository.restorePurchases(),
          repository.restorePurchases(),
        ],
      );
      final SubscriptionState state = states.first;

      expect(state.status, 'grace');
      expect(states.last, state);
      expect(state.planId, 'annual');
      expect(
        state.renewalDate?.millisecondsSinceEpoch,
        verifiedExpiry.millisecondsSinceEpoch,
      );
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

  test('restore single-flight never crosses an account change', () async {
    final Completer<void> restoreStarted = Completer<void>();
    final Completer<void> releaseRestore = Completer<void>();
    final StreamController<List<PurchaseDetails>> controller =
        StreamController<List<PurchaseDetails>>.broadcast();
    final _FakeBillingClient billing = _FakeBillingClient(
      purchaseStreamController: controller,
      productResponse: ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
      onRestorePurchases: () async {
        restoreStarted.complete();
        await releaseRestore.future;
        final PurchaseDetails purchase = PurchaseDetails(
          purchaseID: 'restore-account-change',
          productID: 'chronospark_premium_monthly',
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
    final sb.SupabaseClient client = await _authorityClient((request) async {
      return http.Response(
        '[]',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: billing,
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
      supabaseClient: client,
      httpClient: MockClient((request) async {
        fail('Receipt verification must not run after an account change.');
      }),
    );

    final Future<SubscriptionState> userOneRestore = repository
        .restorePurchases();
    await restoreStarted.future;
    await client.auth.signInWithPassword(
      email: 'user-2@example.com',
      password: 'password',
    );

    await expectLater(repository.restorePurchases, throwsStateError);
    releaseRestore.complete();
    await expectLater(userOneRestore, throwsStateError);
    expect(billing.restoreCalls, 1);

    repository.dispose();
    await controller.close();
  });

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
    'restored unknown product with mismatched verification remains locked',
    () async {
      final DateTime verifiedExpiry = DateTime.now().toUtc().add(
        const Duration(days: 9),
      );
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
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'valid': true,
                  'productId': 'chronospark_premium_monthly',
                  'status': 'active',
                  'expiryTimeMs': verifiedExpiry.millisecondsSinceEpoch,
                }),
                200,
              );
            }),
          );

      final SubscriptionState state = await repository.restorePurchases();

      expect(state.planId, isNull);
      expect(state.isActive, isFalse);
      expect(state.status, 'verification_failed');
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

      expect(first.status, 'verification_failed');
      expect(second.status, 'verification_failed');
      expect(billing.completePurchaseCalls, 2);

      repository.dispose();
      await controller.close();
    },
  );

  test(
    'authority refresh is single-flight and persists the owner status row',
    () async {
      final DateTime expiry = DateTime.now().toUtc().add(
        const Duration(days: 12),
      );
      int statusRequests = 0;
      final sb.SupabaseClient client = await _authorityClient((request) async {
        statusRequests += 1;
        expect(request.url.queryParameters['user_id'], 'eq.user-1');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'user-1',
              'plan_id': 'premium_monthly',
              'product_id': 'chronospark_premium_monthly',
              'status': 'grace',
              'is_active': true,
              'expires_at': expiry.toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: secureStore,
            supabaseClient: client,
          );

      final List<SubscriptionState> refreshed =
          await Future.wait(<Future<SubscriptionState>>[
            repository.refreshSubscriptionState(force: true),
            repository.refreshSubscriptionState(force: true),
          ]);
      final SubscriptionState cached = await repository
          .refreshSubscriptionState();

      expect(statusRequests, 1);
      expect(refreshed.every((state) => state.isActive), isTrue);
      expect(cached.status, 'grace');
      expect(cached.planId, 'monthly');
      expect(cached.renewalDate, isNotNull);
      expect(cached.renewalDate!.isBefore(expiry), isTrue);
      expect(
        cached.renewalDate!.difference(DateTime.now().toUtc()),
        greaterThan(const Duration(hours: 23, minutes: 59)),
      );
      final Map<String, dynamic> persisted =
          jsonDecode(
                (await secureStore.readString(
                  'paywall_subscription_state_v1.account.user-1',
                ))!,
              )
              as Map<String, dynamic>;
      expect(persisted['expirySource'], 'google_play_server');

      repository.dispose();
    },
  );

  test(
    'forced refresh supersedes an older same-account lifecycle request',
    () async {
      final Completer<void> firstStarted = Completer<void>();
      final Completer<void> releaseFirst = Completer<void>();
      int requests = 0;
      final sb.SupabaseClient client = await _authorityClient((request) async {
        requests += 1;
        if (requests == 1) {
          firstStarted.complete();
          await releaseFirst.future;
          return http.Response(
            '[]',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'user-1',
              'plan_id': 'premium_yearly',
              'product_id': 'chronospark_premium_annual',
              'status': 'active',
              'is_active': true,
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
            supabaseClient: client,
          );

      final Future<SubscriptionState> lifecycleRefresh = repository
          .refreshSubscriptionState();
      await firstStarted.future;
      final SubscriptionState forced = await repository
          .refreshSubscriptionState(force: true);
      releaseFirst.complete();
      final SubscriptionState obsolete = await lifecycleRefresh;

      expect(requests, 2);
      expect(forced.isActive, isTrue);
      expect(obsolete.isActive, isTrue);
      repository.dispose();
    },
  );

  test(
    'same-account persistence commits the newest authority revision last',
    () async {
      final _GateFirstWriteBackend backend = _GateFirstWriteBackend(
        gatedKey: 'paywall_subscription_state_v1.account.user-1',
      );
      bool activeResponse = true;
      final sb.SupabaseClient client = await _authorityClient((request) async {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 'user-1',
              'plan_id': 'premium_yearly',
              'product_id': 'chronospark_premium_annual',
              'status': activeResponse ? 'active' : 'revoked',
              'is_active': activeResponse,
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 30))
                  .toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SecureStore secureStore = SecureStore(backend: backend);
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: secureStore,
            supabaseClient: client,
          );

      final Future<SubscriptionState> older = repository
          .refreshSubscriptionState();
      await backend.firstWriteStarted.future;
      activeResponse = false;
      final Future<SubscriptionState> newer = repository
          .refreshSubscriptionState(force: true);
      await Future<void>.delayed(Duration.zero);
      backend.releaseFirstWrite.complete();
      await Future.wait(<Future<SubscriptionState>>[older, newer]);
      final Map<String, dynamic> persisted =
          jsonDecode(
                (await secureStore.readString(
                  'paywall_subscription_state_v1.account.user-1',
                ))!,
              )
              as Map<String, dynamic>;

      expect(persisted['isActive'], isFalse);
      expect(persisted['status'], 'revoked');
      repository.dispose();
    },
  );

  test('authority cooldown and cache never cross accounts', () async {
    final DateTime expiry = DateTime.now().toUtc().add(
      const Duration(days: 10),
    );
    int statusRequests = 0;
    final sb.SupabaseClient client = await _authorityClient((request) async {
      statusRequests += 1;
      final String requestedUser = request.url.queryParameters['user_id']!;
      if (requestedUser == 'eq.user-2') {
        return http.Response(
          '[]',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': 'user-1',
            'plan_id': 'premium_monthly',
            'product_id': 'chronospark_premium_monthly',
            'status': 'active',
            'is_active': true,
            'expires_at': expiry.toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _emptyBillingClient(),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      supabaseClient: client,
    );

    expect(
      (await repository.refreshSubscriptionState(force: true)).isActive,
      isTrue,
    );
    await client.auth.signInWithPassword(
      email: 'user-2@example.com',
      password: 'password',
    );
    final SubscriptionState userTwo = await repository
        .refreshSubscriptionState();

    expect(statusRequests, 2);
    expect(userTwo.isActive, isFalse);
    expect((await repository.getUserSubscriptionState()).isActive, isFalse);

    repository.dispose();
  });

  test(
    'an obsolete in-flight authority result cannot overwrite a new account',
    () async {
      final Completer<void> userOneStarted = Completer<void>();
      final Completer<void> releaseUserOne = Completer<void>();
      final DateTime expiry = DateTime.now().toUtc().add(
        const Duration(days: 20),
      );
      int statusRequests = 0;
      final sb.SupabaseClient client = await _authorityClient((request) async {
        statusRequests += 1;
        final String requestedUser = request.url.queryParameters['user_id']!;
        if (requestedUser == 'eq.user-1') {
          userOneStarted.complete();
          await releaseUserOne.future;
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{
                'user_id': 'user-1',
                'plan_id': 'premium_yearly',
                'product_id': 'chronospark_premium_annual',
                'status': 'active',
                'is_active': true,
                'expires_at': expiry.toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
            ]),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: secureStore,
            supabaseClient: client,
          );

      final Future<SubscriptionState> userOneRefresh = repository
          .refreshSubscriptionState(force: true);
      await userOneStarted.future;
      await client.auth.signInWithPassword(
        email: 'user-2@example.com',
        password: 'password',
      );
      final SubscriptionState userTwo = await repository
          .refreshSubscriptionState(force: true);
      releaseUserOne.complete();
      final SubscriptionState staleUserOne = await userOneRefresh;

      expect(statusRequests, 2);
      expect(userTwo.isActive, isFalse);
      expect(staleUserOne.isActive, isFalse);
      final Map<String, dynamic> persisted =
          jsonDecode(
                (await secureStore.readString(
                  'paywall_subscription_state_v1.account.user-2',
                ))!,
              )
              as Map<String, dynamic>;
      expect(persisted['authorityUserId'], 'user-2');

      repository.dispose();
    },
  );

  test('authority refresh revokes a locally active subscription', () async {
    final DateTime expiry = DateTime.now().toUtc().add(
      const Duration(days: 30),
    );
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      'paywall_subscription_state_v1',
      jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': expiry.toIso8601String(),
        'expirySource': 'google_play_server',
      }),
    );
    final sb.SupabaseClient client = await _authorityClient((request) async {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': 'user-1',
            'plan_id': 'premium_yearly',
            'product_id': 'chronospark_premium_annual',
            'status': 'revoked',
            'is_active': false,
            'expires_at': expiry.toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _emptyBillingClient(),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: secureStore,
      supabaseClient: client,
    );

    final SubscriptionState state = await repository.refreshSubscriptionState(
      force: true,
    );

    expect(state.isActive, isFalse);
    expect(state.status, 'revoked');
    expect((await repository.checkEntitlement()).isEntitled, isFalse);

    repository.dispose();
  });

  test(
    'transient failure preserves a short lease but permission failure locks',
    () async {
      final DateTime expiry = DateTime.now().toUtc().add(
        const Duration(days: 2),
      );
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await secureStore.writeString(
        'paywall_subscription_state_v1',
        jsonEncode(<String, dynamic>{
          'isActive': true,
          'status': 'active',
          'planId': 'monthly',
          'renewalDate': expiry.toIso8601String(),
          'expirySource': 'google_play_server',
          'authorityUserId': 'user-1',
          'authorityVerifiedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      int responseStatus = 503;
      final sb.SupabaseClient client = await _authorityClient((request) async {
        return http.Response(
          responseStatus == 503
              ? '{"message":"temporarily unavailable","code":"PGRST000"}'
              : '{"message":"forbidden","code":"42501"}',
          responseStatus,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: secureStore,
            supabaseClient: client,
          );

      final SubscriptionState state = await Logger.withMutedErrors(
        () => repository.refreshSubscriptionState(force: true),
      );

      expect(state.isActive, isTrue);
      expect(state.renewalDate, isNotNull);
      expect(state.renewalDate!.isBefore(expiry), isTrue);
      expect(
        state.renewalDate!.difference(DateTime.now().toUtc()),
        greaterThan(const Duration(hours: 23, minutes: 59)),
      );

      responseStatus = 403;
      final SubscriptionState denied = await Logger.withMutedErrors(
        () => repository.refreshSubscriptionState(force: true),
      );
      expect(denied.isActive, isFalse);
      expect(denied.status, 'authority_unavailable');

      repository.dispose();
    },
  );

  test('offline lease rejects stale and future verification clocks', () async {
    for (final DateTime verifiedAt in <DateTime>[
      DateTime.now().toUtc().subtract(const Duration(hours: 25)),
      DateTime.now().toUtc().add(const Duration(minutes: 10)),
    ]) {
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await secureStore.writeString(
        'paywall_subscription_state_v1.account.user-1',
        jsonEncode(<String, dynamic>{
          'isActive': true,
          'status': 'active',
          'planId': 'annual',
          'renewalDate': DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .toIso8601String(),
          'expirySource': 'google_play_server',
          'authorityUserId': 'user-1',
          'authorityVerifiedAt': verifiedAt.toIso8601String(),
        }),
      );
      final sb.SupabaseClient client = await _authorityClient((request) async {
        return http.Response(
          '{"message":"offline","code":"PGRST000"}',
          503,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: secureStore,
            supabaseClient: client,
            authorityRequestTimeout: const Duration(milliseconds: 20),
          );

      final SubscriptionState state = await Logger.withMutedErrors(
        () => repository.refreshSubscriptionState(force: true),
      );

      expect(state.isActive, isFalse);
      expect(state.status, 'authority_unavailable');
      repository.dispose();
    }
  });

  test('authority timeout settles through the valid offline lease', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      'paywall_subscription_state_v1.account.user-1',
      jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': DateTime.now()
            .toUtc()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'expirySource': 'google_play_server',
        'authorityUserId': 'user-1',
        'authorityVerifiedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    final Completer<http.Response> never = Completer<http.Response>();
    final sb.SupabaseClient client = await _authorityClient(
      (request) => never.future,
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _emptyBillingClient(),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: secureStore,
      supabaseClient: client,
      authorityRequestTimeout: const Duration(milliseconds: 10),
    );

    final SubscriptionState state = await Logger.withMutedErrors(
      () => repository.refreshSubscriptionState(force: true),
    );

    expect(state.isActive, isTrue);
    repository.dispose();
  });

  test('timeout locks without a lease and ignores a late active row', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final Completer<http.Response> delayed = Completer<http.Response>();
    final sb.SupabaseClient client = await _authorityClient(
      (request) => delayed.future,
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _emptyBillingClient(),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: secureStore,
      supabaseClient: client,
      authorityRequestTimeout: const Duration(milliseconds: 10),
    );

    final SubscriptionState timedOut = await Logger.withMutedErrors(
      () => repository.refreshSubscriptionState(force: true),
    );
    delayed.complete(
      http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': 'user-1',
            'plan_id': 'premium_yearly',
            'product_id': 'chronospark_premium_annual',
            'status': 'active',
            'is_active': true,
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(days: 30))
                .toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final SubscriptionState afterLateResponse = await repository
        .getUserSubscriptionState();
    final Map<String, dynamic> persisted =
        jsonDecode(
              (await secureStore.readString(
                'paywall_subscription_state_v1.account.user-1',
              ))!,
            )
            as Map<String, dynamic>;

    expect(timedOut.isActive, isFalse);
    expect(timedOut.status, 'authority_unavailable');
    expect(afterLateResponse.isActive, isFalse);
    expect(persisted['isActive'], isFalse);
    repository.dispose();
  });

  test('account-scoped cache survives cold-start account isolation', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    final DateTime now = DateTime.now().toUtc();
    await secureStore.writeString(
      'paywall_subscription_state_v1.account.user-1',
      jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': now.add(const Duration(days: 30)).toIso8601String(),
        'expirySource': 'google_play_server',
        'authorityUserId': 'user-1',
        'authorityVerifiedAt': now.toIso8601String(),
      }),
    );
    await secureStore.writeString(
      'paywall_subscription_state_v1.account.user-2',
      jsonEncode(<String, dynamic>{
        'isActive': false,
        'status': 'free',
        'expirySource': null,
        'authorityUserId': 'user-2',
        'authorityVerifiedAt': now.toIso8601String(),
      }),
    );
    final Completer<http.Response> never = Completer<http.Response>();
    final sb.SupabaseClient userOneClient = await _authorityClient(
      (request) => never.future,
    );
    final sb.SupabaseClient userTwoClient = await _authorityClient(
      (request) => never.future,
    );
    await userTwoClient.auth.signInWithPassword(
      email: 'user-2@example.com',
      password: 'password',
    );
    final GooglePlayPaywallRepository userOneRepository =
        GooglePlayPaywallRepository(
          billingClient: _emptyBillingClient(),
          paywallTestingModeOverride: false,
          sharedPreferencesLoader: SharedPreferences.getInstance,
          secureStore: secureStore,
          supabaseClient: userOneClient,
          authorityRequestTimeout: const Duration(milliseconds: 10),
        );
    final GooglePlayPaywallRepository userTwoRepository =
        GooglePlayPaywallRepository(
          billingClient: _emptyBillingClient(),
          paywallTestingModeOverride: false,
          sharedPreferencesLoader: SharedPreferences.getInstance,
          secureStore: secureStore,
          supabaseClient: userTwoClient,
          authorityRequestTimeout: const Duration(milliseconds: 10),
        );

    final SubscriptionState userOne = await Logger.withMutedErrors(
      () => userOneRepository.refreshSubscriptionState(force: true),
    );
    final SubscriptionState userTwo = await userTwoRepository
        .getUserSubscriptionState();

    expect(userOne.isActive, isTrue);
    expect(userTwo.isActive, isFalse);
    expect(userTwo.status, 'free');
    userOneRepository.dispose();
    userTwoRepository.dispose();
  });

  test('authority rejects an expiry beyond the maximum window', () async {
    final sb.SupabaseClient client = await _authorityClient((request) async {
      return http.Response(
        jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'user_id': 'user-1',
            'plan_id': 'premium_yearly',
            'product_id': 'chronospark_premium_annual',
            'status': 'active',
            'is_active': true,
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(days: 401))
                .toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _emptyBillingClient(),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
      supabaseClient: client,
    );

    final SubscriptionState state = await repository.refreshSubscriptionState(
      force: true,
    );

    expect(state.isActive, isFalse);
    expect(state.status, 'authority_invalid');
    repository.dispose();
  });

  test(
    'missing authority row enables one legacy Play restore attempt',
    () async {
      final String legacyState = jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': DateTime.now()
            .add(const Duration(days: 300))
            .toIso8601String(),
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'paywall_subscription_state_v1': legacyState,
      });
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
      await secureStore.writeString('entitlement_owner_user_id_v1', 'user-1');
      final sb.SupabaseClient client = await _authorityClient((request) async {
        return http.Response(
          '[]',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: secureStore,
            supabaseClient: client,
          );

      final SubscriptionState state = await repository.refreshSubscriptionState(
        force: true,
      );

      expect(state.isActive, isFalse);
      expect(repository.shouldRestoreLegacySubscription, isTrue);

      repository.dispose();
    },
  );

  test(
    'ownerless legacy state never auto-restores for a signed-in account',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'paywall_subscription_state_v1': jsonEncode(<String, dynamic>{
          'isActive': true,
          'status': 'active',
          'planId': 'annual',
          'renewalDate': DateTime.now()
              .add(const Duration(days: 300))
              .toIso8601String(),
        }),
      });
      final sb.SupabaseClient client = await _authorityClient((request) async {
        return http.Response(
          '[]',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final GooglePlayPaywallRepository repository =
          GooglePlayPaywallRepository(
            billingClient: _emptyBillingClient(),
            paywallTestingModeOverride: false,
            sharedPreferencesLoader: SharedPreferences.getInstance,
            secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
            supabaseClient: client,
          );

      await repository.refreshSubscriptionState(force: true);

      expect(repository.shouldRestoreLegacySubscription, isFalse);
      expect(await repository.restoreLegacySubscription(), isNull);
      repository.dispose();
    },
  );

  test('transient outage preserves a trusted legacy candidate', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      'paywall_subscription_state_v1',
      jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': DateTime.now()
            .add(const Duration(days: 300))
            .toIso8601String(),
      }),
    );
    await secureStore.writeString('entitlement_owner_user_id_v1', 'user-1');
    final Completer<http.Response> never = Completer<http.Response>();
    final sb.SupabaseClient offlineClient = await _authorityClient(
      (request) => never.future,
    );
    final GooglePlayPaywallRepository offlineRepository =
        GooglePlayPaywallRepository(
          billingClient: _emptyBillingClient(),
          paywallTestingModeOverride: false,
          sharedPreferencesLoader: SharedPreferences.getInstance,
          secureStore: secureStore,
          supabaseClient: offlineClient,
          authorityRequestTimeout: const Duration(milliseconds: 10),
        );
    await Logger.withMutedErrors(
      () => offlineRepository.refreshSubscriptionState(force: true),
    );
    offlineRepository.dispose();

    final sb.SupabaseClient onlineClient = await _authorityClient((
      request,
    ) async {
      return http.Response(
        '[]',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final GooglePlayPaywallRepository reconstructed =
        GooglePlayPaywallRepository(
          billingClient: _emptyBillingClient(),
          paywallTestingModeOverride: false,
          sharedPreferencesLoader: SharedPreferences.getInstance,
          secureStore: secureStore,
          supabaseClient: onlineClient,
        );
    await reconstructed.refreshSubscriptionState(force: true);

    expect(reconstructed.shouldRestoreLegacySubscription, isTrue);
    reconstructed.dispose();
  });

  test('failed legacy restore persists a retry backoff', () async {
    final String legacyState = jsonEncode(<String, dynamic>{
      'isActive': true,
      'status': 'active',
      'planId': 'annual',
      'renewalDate': DateTime.now()
          .add(const Duration(days: 300))
          .toIso8601String(),
    });
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString('paywall_subscription_state_v1', legacyState);
    await secureStore.writeString('entitlement_owner_user_id_v1', 'user-1');
    final sb.SupabaseClient client = await _authorityClient((request) async {
      return http.Response(
        '[]',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _FakeBillingClient(
        productResponse: ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
        onRestorePurchases: () => Future<void>.error(Exception('offline')),
      ),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: secureStore,
      supabaseClient: client,
      receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
    );
    await repository.refreshSubscriptionState(force: true);

    final SubscriptionState? restored = await Logger.withMutedErrors(
      repository.restoreLegacySubscription,
    );
    final Map<String, dynamic> persisted =
        jsonDecode(
              (await secureStore.readString(
                'paywall_subscription_state_v1.account.user-1',
              ))!,
            )
            as Map<String, dynamic>;

    expect(restored, isNull);
    expect(repository.shouldRestoreLegacySubscription, isFalse);
    expect(persisted['legacyRestoreAttempted'], isFalse);
    expect(
      DateTime.tryParse('${persisted['legacyRestoreNextRetryAt']}'),
      isNotNull,
    );
    repository.dispose();
  });

  test('inactive legacy restore backoff survives reconstruction', () async {
    final SecureStore secureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    await secureStore.writeString(
      'paywall_subscription_state_v1',
      jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': DateTime.now()
            .add(const Duration(days: 300))
            .toIso8601String(),
      }),
    );
    await secureStore.writeString('entitlement_owner_user_id_v1', 'user-1');
    final sb.SupabaseClient client = await _authorityClient((request) async {
      return http.Response(
        '[]',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final StreamController<List<PurchaseDetails>> controller =
        StreamController<List<PurchaseDetails>>.broadcast();
    final _FakeBillingClient billing = _FakeBillingClient(
      purchaseStreamController: controller,
      productResponse: ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>[],
      ),
      onRestorePurchases: () async {
        controller.add(<PurchaseDetails>[
          PurchaseDetails(
            purchaseID: 'legacy-unknown',
            productID: 'unknown-product',
            verificationData: PurchaseVerificationData(
              localVerificationData: 'local-token',
              serverVerificationData: 'server-token',
              source: 'google_play',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.restored,
          ),
        ]);
      },
    );
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: billing,
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
      secureStore: secureStore,
      supabaseClient: client,
      receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'valid': true,
            'productId': 'unknown-product',
            'status': 'active',
            'expiryTimeMs': DateTime.now()
                .toUtc()
                .add(const Duration(days: 30))
                .millisecondsSinceEpoch,
          }),
          200,
        );
      }),
    );
    await repository.refreshSubscriptionState(force: true);
    final SubscriptionState? restored = await repository
        .restoreLegacySubscription();
    repository.dispose();
    await controller.close();

    final sb.SupabaseClient reconstructedClient = await _authorityClient((
      request,
    ) async {
      return http.Response(
        '[]',
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final _FakeBillingClient reconstructedBilling = _emptyBillingClient();
    final GooglePlayPaywallRepository reconstructed =
        GooglePlayPaywallRepository(
          billingClient: reconstructedBilling,
          paywallTestingModeOverride: false,
          sharedPreferencesLoader: SharedPreferences.getInstance,
          secureStore: secureStore,
          supabaseClient: reconstructedClient,
          receiptVerifyEndpoint: 'https://api.chronospark.app/verify',
        );
    await reconstructed.refreshSubscriptionState(force: true);

    expect(restored, isNull);
    expect(reconstructed.shouldRestoreLegacySubscription, isFalse);
    expect(await reconstructed.restoreLegacySubscription(), isNull);
    expect(reconstructedBilling.restoreCalls, 0);
    reconstructed.dispose();
  });

  test('cancelSubscription updates persisted user state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'paywall_subscription_state_v1': jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'monthly',
        'renewalDate': DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String(),
        'expirySource': 'google_play_server',
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
        'expirySource': 'google_play_server',
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

  test('implausible persisted expiry never grants entitlement', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'paywall_subscription_state_v1': jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': DateTime.now()
            .add(const Duration(days: 401))
            .toIso8601String(),
        'expirySource': 'google_play_server',
      }),
    });
    final GooglePlayPaywallRepository repository = GooglePlayPaywallRepository(
      billingClient: _emptyBillingClient(),
      paywallTestingModeOverride: false,
      sharedPreferencesLoader: SharedPreferences.getInstance,
    );

    final SubscriptionState state = await repository.getUserSubscriptionState();
    final entitlement = await repository.checkEntitlement(featureId: 'premium');

    expect(state.isActive, isFalse);
    expect(state.renewalDate, isNull);
    expect(entitlement.isEntitled, isFalse);
    repository.dispose();
  });

  test(
    'migrates unverified legacy state without granting entitlement',
    () async {
      final DateTime renewal = DateTime.now().add(const Duration(days: 14));
      final String legacyState = jsonEncode(<String, dynamic>{
        'isActive': true,
        'status': 'active',
        'planId': 'annual',
        'renewalDate': renewal.toIso8601String(),
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'paywall_subscription_state_v1': legacyState,
      });
      final SecureStore secureStore = SecureStore(
        backend: InMemorySecureStoreBackend(),
      );
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
            secureStore: secureStore,
          );

      final SubscriptionState restored = await repository
          .getUserSubscriptionState();
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(restored.isActive, isFalse);
      expect(restored.planId, 'annual');
      expect(
        await secureStore.readString('paywall_subscription_state_v1'),
        legacyState,
      );
      expect(prefs.containsKey('paywall_subscription_state_v1'), isFalse);

      final SubscriptionState cancelled = await repository.cancelSubscription();
      final Map<String, dynamic> securedCancellation =
          jsonDecode(
                (await secureStore.readString(
                  'paywall_subscription_state_v1',
                ))!,
              )
              as Map<String, dynamic>;
      expect(cancelled.status, 'cancelled');
      expect(securedCancellation['status'], 'cancelled');

      repository.dispose();
    },
  );

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
          'expirySource': 'google_play_server',
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

_FakeBillingClient _emptyBillingClient() {
  return _FakeBillingClient(
    productResponse: ProductDetailsResponse(
      productDetails: const <ProductDetails>[],
      notFoundIDs: const <String>[],
    ),
  );
}

Future<sb.SupabaseClient> _authorityClient(
  Future<http.Response> Function(http.Request request) statusHandler,
) async {
  final sb.SupabaseClient client = sb.SupabaseClient(
    'https://chronospark.example.com',
    'anon-key',
    httpClient: MockClient((http.Request request) async {
      if (request.url.path.endsWith('/auth/v1/token')) {
        final Map<String, dynamic> credentials =
            jsonDecode(request.body) as Map<String, dynamic>;
        final String email = credentials['email']?.toString() ?? '';
        final String userId = email.startsWith('user-2') ? 'user-2' : 'user-1';
        return http.Response(
          jsonEncode(<String, dynamic>{
            'access_token': 'access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh-token',
            'user': <String, dynamic>{
              'id': userId,
              'aud': 'authenticated',
              'email': '$userId@example.com',
              'created_at': '2026-08-21T00:00:00.000Z',
              'email_confirmed_at': '2026-08-21T00:00:00.000Z',
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/rest/v1/monetization_subscription_statuses') {
        final http.Response response = await statusHandler(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    }),
    authOptions: const sb.AuthClientOptions(
      authFlowType: sb.AuthFlowType.implicit,
    ),
  );
  await client.auth.signInWithPassword(
    email: 'user-1@example.com',
    password: 'password',
  );
  return client;
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

class _GateFirstWriteBackend implements SecureStoreBackend {
  _GateFirstWriteBackend({required this.gatedKey});

  final String gatedKey;
  final Map<String, String> _values = <String, String>{};
  final Completer<void> firstWriteStarted = Completer<void>();
  final Completer<void> releaseFirstWrite = Completer<void>();
  bool _gated = false;

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.unmodifiable(_values);

  @override
  Future<void> write({required String key, required String value}) async {
    if (key == gatedKey && !_gated) {
      _gated = true;
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    _values[key] = value;
  }
}
