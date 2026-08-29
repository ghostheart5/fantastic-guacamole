import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> _kProductIds = <String, String>{
  'monthly': 'chronospark_premium_monthly',
  'annual': 'chronospark_premium_annual',
};
const String _kPrefsKey = 'paywall_subscription_state_v1';
const int _kMaxDateTimeEpochMilliseconds = 8640000000000000;
const Set<String> _kServerAccessStatuses = <String>{
  'active',
  'grace',
  'cancelled',
};

/// Local testing validity window per plan.
///
/// The renewal date gates local re-entitlement on launch, so an annual
/// subscriber given a 30-day window would be locked out ~11 months early.
const Duration _kMonthlyPeriod = Duration(days: 30);
const Duration _kAnnualPeriod = Duration(days: 365);

DateTime _testingRenewalDateFor(String? planId) {
  return DateTime.now().add(
    planId == 'annual' ? _kAnnualPeriod : _kMonthlyPeriod,
  );
}

class _VerifiedSubscription {
  const _VerifiedSubscription({required this.expiry, required this.status});

  final DateTime expiry;
  final String status;
}

abstract class BillingClient {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseBillingClient implements BillingClient {
  InAppPurchaseBillingClient([InAppPurchase? iap])
    : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) {
    return _iap.queryProductDetails(ids);
  }

  @override
  Future<void> restorePurchases() {
    return _iap.restorePurchases();
  }
}

class GooglePlayPaywallRepository implements IPaywallRepository {
  GooglePlayPaywallRepository({
    BillingClient? billingClient,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
    http.Client? httpClient,
    bool? paywallTestingModeOverride,
    String? receiptVerifyEndpoint,
    SecureStore? secureStore,
  }) : _billingClient = billingClient ?? InAppPurchaseBillingClient(),
       _sharedPreferencesLoader =
           sharedPreferencesLoader ?? SharedPreferences.getInstance,
       _httpClient = httpClient ?? http.Client(),
       _paywallTestingMode = paywallTestingModeOverride ?? paywallTestingMode,
       // Named public parameter intentionally maps to a private field.
       // ignore: prefer_initializing_formals
       _secureStore = secureStore,
       _receiptVerifyEndpoint =
           receiptVerifyEndpoint ?? Env.receiptVerifyEndpoint {
    _purchaseSub = _billingClient.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object error) => Logger.error('IAP stream error', error),
    );
    _initialization = _loadPersistedState();
  }

  final BillingClient _billingClient;
  final Future<SharedPreferences> Function() _sharedPreferencesLoader;
  final http.Client _httpClient;
  final bool _paywallTestingMode;
  final SecureStore? _secureStore;
  final String _receiptVerifyEndpoint;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;
  late final Future<void> _initialization;

  SubscriptionState _state = const SubscriptionState(
    isActive: false,
    status: 'locked',
    source: 'google_play',
  );
  bool _hasAuthoritativeExpiry = false;

  final Map<String, Completer<SubscriptionState>> _pending =
      <String, Completer<SubscriptionState>>{};

  bool get _hasReceiptVerification {
    return parseSecureHttpsEndpoint(_receiptVerifyEndpoint) != null;
  }

  static const List<PaywallPlan> _plans = <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Premium Monthly',
      priceLabel: 'from \$9.99 / month',
      description:
          'Best for active users who want full Smart Planner guidance and recurring credits.',
      aiCreditsIncluded: 300,
      benefits: <String>[
        '300 smart guidance credits every month',
        'Priority smart suggestions',
        'Advanced memory and signals',
      ],
      isFeatured: true,
    ),
    PaywallPlan(
      id: 'annual',
      title: 'Premium Yearly',
      priceLabel: 'from \$89.99 / year',
      description:
          'Best value for users committed to long-term habit building.',
      aiCreditsIncluded: 360,
      benefits: <String>[
        '360 smart guidance credits every month',
        'Yearly billing discount',
        'Unlimited access to premium tools',
      ],
    ),
  ];

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    await _initialization;
    if (_paywallTestingMode) {
      return _plans;
    }

    if (!_hasReceiptVerification) {
      return _plans
          .map(
            (PaywallPlan plan) => PaywallPlan(
              id: plan.id,
              title: plan.title,
              priceLabel: plan.priceLabel,
              description: plan.description,
              aiCreditsIncluded: plan.aiCreditsIncluded,
              freeTrialDays: 0,
              benefits: plan.benefits,
              isAvailable: false,
              isFeatured: plan.isFeatured,
            ),
          )
          .toList(growable: false);
    }

    try {
      final Set<String> ids = _kProductIds.values.toSet();
      final ProductDetailsResponse response = await _billingClient
          .queryProductDetails(ids);
      if (response.error != null || response.productDetails.isEmpty) {
        return _plans;
      }

      return _plans
          .map((PaywallPlan plan) {
            final String? gpId = _kProductIds[plan.id];
            ProductDetails? detail;
            for (final ProductDetails candidate in response.productDetails) {
              if (candidate.id == gpId) {
                detail = candidate;
                break;
              }
            }
            return PaywallPlan(
              id: plan.id,
              title: plan.title,
              priceLabel: detail?.price ?? plan.priceLabel,
              description: plan.description,
              aiCreditsIncluded: plan.aiCreditsIncluded,
              freeTrialDays: 0,
              benefits: plan.benefits
                  .where(
                    (String benefit) =>
                        !benefit.toLowerCase().contains('free trial'),
                  )
                  .toList(growable: false),
              isAvailable: detail != null,
              isFeatured: plan.isFeatured,
            );
          })
          .toList(growable: false);
    } on Exception catch (error) {
      Logger.error('getAvailablePlans failed', error);
      return _plans;
    }
  }

  @override
  Future<PaywallEntity> getPaywallConfig() async {
    await _initialization;
    final bool billingReady = _paywallTestingMode || _hasReceiptVerification;
    return PaywallEntity(
      featureId: 'premium',
      title: _paywallTestingMode
          ? 'Unlocked for testing'
          : (Env.isAiProxyConfigured
                ? 'AI Credits + Premium'
                : 'Smart Credits + Premium'),
      body: _paywallTestingMode
          ? 'Premium gates are bypassed in this build.'
          : (billingReady
                ? (Env.isAiProxyConfigured
                      ? 'Unlock AI credits, premium planning guidance, deeper memory, and advanced tools.'
                      : 'Unlock smart credits, premium planning guidance, deeper memory, and advanced tools.')
                : 'Purchases are temporarily unavailable while billing verification is being finalized.'),
      plans: await getAvailablePlans(),
      isUnlocked: _paywallTestingMode || _isSubscriptionActive,
    );
  }

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    await _initialization;
    if (_paywallTestingMode) {
      return Entitlement(
        featureId: featureId ?? 'premium',
        isEntitled: true,
        source: 'testing_mode',
      );
    }

    return Entitlement(
      featureId: featureId ?? 'premium',
      isEntitled: _isSubscriptionActive,
      source: _state.source,
      expiresAt: _state.renewalDate,
    );
  }

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    await _initialization;
    if (_paywallTestingMode) {
      _state = SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        planId: planId,
        renewalDate: _testingRenewalDateFor(planId),
        isTesting: true,
      );
      return _state;
    }

    if (!_hasReceiptVerification) {
      throw StateError(
        'Purchases are temporarily unavailable. Please update and try again soon.',
      );
    }

    final String? gpId = _kProductIds[planId];
    if (gpId == null) {
      throw ArgumentError('Unknown plan: $planId');
    }

    final ProductDetailsResponse response = await _billingClient
        .queryProductDetails(<String>{gpId});
    if (response.productDetails.isEmpty) {
      throw StateError('Product $gpId not found in Google Play.');
    }

    final Completer<SubscriptionState> completer =
        Completer<SubscriptionState>();
    _pending[gpId] = completer;

    final PurchaseParam param = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await _billingClient.buyNonConsumable(purchaseParam: param);

    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        _pending.remove(gpId);
        throw TimeoutException('Purchase timed out.');
      },
    );
  }

  @override
  Future<SubscriptionState> cancelSubscription() async {
    await _initialization;
    _state = SubscriptionState(
      isActive: false,
      status: 'cancelled',
      source: 'google_play',
      planId: _state.planId,
      renewalDate: _state.renewalDate,
    );
    await _persistState();
    return _state;
  }

  @override
  Future<SubscriptionState> restorePurchases() async {
    await _initialization;
    if (_paywallTestingMode) {
      _state = SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        planId: _state.planId ?? 'annual',
        renewalDate: _testingRenewalDateFor(_state.planId ?? 'annual'),
        isTesting: true,
      );
      return _state;
    }

    if (!_hasReceiptVerification) {
      throw StateError(
        'Restore is temporarily unavailable. Please update and try again soon.',
      );
    }

    final Completer<SubscriptionState> completer =
        Completer<SubscriptionState>();
    _pending['__restore__'] = completer;
    await _billingClient.restorePurchases();

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove('__restore__');
        return _state;
      },
    );
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() async {
    await _initialization;
    if (_isSubscriptionActive || !_state.isActive) {
      return _state;
    }
    return SubscriptionState(
      isActive: false,
      status: 'expired',
      source: _state.source,
      planId: _state.planId,
      renewalDate: _state.renewalDate,
      isTesting: _state.isTesting,
    );
  }

  void dispose() {
    _purchaseSub.cancel();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final _VerifiedSubscription? verification =
            await _verifiedSubscriptionFromServer(purchase);
        String? planId;
        for (final MapEntry<String, String> entry in _kProductIds.entries) {
          if (entry.value == purchase.productID) {
            planId = entry.key;
            break;
          }
        }
        if (verification != null && planId != null) {
          _state = SubscriptionState(
            isActive: true,
            status: verification.status,
            source: 'google_play',
            planId: planId,
            renewalDate: verification.expiry,
          );
          _hasAuthoritativeExpiry = true;
          await _persistState();
          _pending[purchase.productID]?.complete(_state);
          _pending['__restore__']?.complete(_state);
        } else {
          const SubscriptionState failed = SubscriptionState(
            isActive: false,
            status: 'verification_failed',
            source: 'google_play',
          );
          _pending[purchase.productID]?.complete(failed);
          _pending['__restore__']?.complete(failed);
        }
        _pending.remove(purchase.productID);
        _pending.remove('__restore__');
        await _billingClient.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        Logger.error('IAP purchase error', purchase.error);
        _pending[purchase.productID]?.completeError(
          purchase.error ?? 'Purchase failed',
        );
        _pending.remove(purchase.productID);
        if (purchase.pendingCompletePurchase) {
          await _billingClient.completePurchase(purchase);
        }
      }
    }
  }

  Future<_VerifiedSubscription?> _verifiedSubscriptionFromServer(
    PurchaseDetails purchase,
  ) async {
    if (!_hasReceiptVerification) {
      Logger.error(
        'Receipt verification is unavailable; purchase remains locked.',
      );
      return null;
    }
    final Uri endpoint = parseSecureHttpsEndpoint(_receiptVerifyEndpoint)!;
    final String? accessToken = currentSupabaseAccessToken();
    if (Env.isProduction && accessToken == null) {
      Logger.error('Receipt verification requires an authenticated session.');
      return null;
    }

    try {
      final http.Response response = await _httpClient
          .post(
            endpoint,
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(<String, String>{
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
              'purchaseType': 'subscription',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        Logger.error('Receipt verify HTTP ${response.statusCode}');
        return null;
      }
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (body['valid'] != true) {
        return null;
      }
      if (body['productId'] != purchase.productID) {
        Logger.error('Receipt verification returned a mismatched product.');
        return null;
      }
      final Object? rawStatus = body['status'];
      if (rawStatus is! String || !_kServerAccessStatuses.contains(rawStatus)) {
        Logger.error('Receipt verification returned an invalid access status.');
        return null;
      }
      final Object? rawExpiry = body['expiryTimeMs'];
      if (rawExpiry is! int ||
          rawExpiry <= 0 ||
          rawExpiry > _kMaxDateTimeEpochMilliseconds) {
        Logger.error(
          'Receipt verification omitted the authoritative expiry time.',
        );
        return null;
      }
      final DateTime expiry = DateTime.fromMillisecondsSinceEpoch(
        rawExpiry,
        isUtc: true,
      );
      if (!expiry.isAfter(DateTime.now().toUtc())) {
        Logger.error('Receipt verification returned an expired subscription.');
        return null;
      }
      return _VerifiedSubscription(expiry: expiry, status: rawStatus);
    } on Exception catch (error) {
      Logger.error('Receipt verification request failed', error);
      return null;
    }
  }

  bool get _isSubscriptionActive {
    if (!_state.isActive) {
      return false;
    }
    if (_paywallTestingMode && _state.isTesting) {
      return true;
    }
    final DateTime? expiry = _state.renewalDate;
    return _hasAuthoritativeExpiry &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc());
  }

  Future<void> _loadPersistedState() async {
    try {
      final SharedPreferences prefs = await _sharedPreferencesLoader();
      if (_secureStore == null) {
        if (Env.isProduction) {
          Logger.error(
            'Secure storage is unavailable in production; using locked paywall state.',
          );
          return;
        }
        final String? fallbackRaw = prefs.getString(_kPrefsKey);
        if (fallbackRaw == null) {
          return;
        }
        final Map<String, dynamic> fallbackMap =
            jsonDecode(fallbackRaw) as Map<String, dynamic>;
        final DateTime? fallbackRenewal = fallbackMap['renewalDate'] != null
            ? DateTime.tryParse(fallbackMap['renewalDate'] as String)
            : null;
        _hasAuthoritativeExpiry =
            fallbackMap['expirySource'] == 'google_play_server';
        final bool fallbackIsActive =
            fallbackMap['isActive'] == true &&
            _hasAuthoritativeExpiry &&
            fallbackRenewal != null &&
            fallbackRenewal.isAfter(DateTime.now().toUtc());
        _state = SubscriptionState(
          isActive: fallbackIsActive,
          status: fallbackMap['status'] as String? ?? 'locked',
          source: 'google_play',
          planId: fallbackMap['planId'] as String?,
          renewalDate: fallbackRenewal,
        );
        return;
      }

      String? raw = await _secureStore.readString(_kPrefsKey);
      raw ??= prefs.getString(_kPrefsKey);
      if (raw == null) {
        return;
      }
      if (prefs.containsKey(_kPrefsKey)) {
        await _secureStore.writeString(_kPrefsKey, raw);
        await prefs.remove(_kPrefsKey);
      }
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      final DateTime? renewal = map['renewalDate'] != null
          ? DateTime.tryParse(map['renewalDate'] as String)
          : null;
      _hasAuthoritativeExpiry = map['expirySource'] == 'google_play_server';
      final bool isActive =
          map['isActive'] == true &&
          _hasAuthoritativeExpiry &&
          renewal != null &&
          renewal.isAfter(DateTime.now().toUtc());
      _state = SubscriptionState(
        isActive: isActive,
        status: map['status'] as String? ?? 'locked',
        source: 'google_play',
        planId: map['planId'] as String?,
        renewalDate: renewal,
      );
    } on Exception catch (error) {
      Logger.error('Failed to load persisted subscription state', error);
    }
  }

  Future<void> _persistState() async {
    try {
      final String encoded = jsonEncode(<String, dynamic>{
        'isActive': _state.isActive,
        'status': _state.status,
        'planId': _state.planId,
        'renewalDate': _state.renewalDate?.toIso8601String(),
        'expirySource': _hasAuthoritativeExpiry ? 'google_play_server' : null,
      });
      if (_secureStore == null) {
        if (Env.isProduction) {
          Logger.error(
            'Secure storage is unavailable in production; paywall state was not persisted.',
          );
          return;
        }
        final SharedPreferences prefs = await _sharedPreferencesLoader();
        await prefs.setString(_kPrefsKey, encoded);
        return;
      }
      await _secureStore.writeString(_kPrefsKey, encoded);
    } on Exception catch (error) {
      Logger.error('Failed to persist subscription state', error);
    }
  }
}
