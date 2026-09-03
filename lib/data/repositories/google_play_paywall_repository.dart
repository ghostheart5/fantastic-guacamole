import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/config/app_config.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/data/account_data_registry.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/network/secure_endpoint.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_subscription_repository.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

const Map<String, String> _kProductIds = <String, String>{
  'monthly': 'chronospark_premium_monthly',
  'annual': 'chronospark_premium_annual',
};
const Map<String, String> _kServerPlanIds = <String, String>{
  'monthly': 'premium_monthly',
  'annual': 'premium_yearly',
};
const String _kPrefsKey = 'paywall_subscription_state_v1';
const String _kLegacyEntitlementOwnerKey = 'entitlement_owner_user_id_v1';
const int _kMaxDateTimeEpochMilliseconds = 8640000000000000;
const Duration _kAuthorityRefreshCooldown = Duration(seconds: 30);
const Duration _kAuthorityOfflineLease = Duration(hours: 24);
const Duration _kMaximumAuthorityExpiry = Duration(days: 400);
const Duration _kAuthorityRequestTimeout = Duration(seconds: 8);
const Duration _kAuthorityFutureClockSkew = Duration(minutes: 5);
const Duration _kLegacyRestoreFailureBackoff = Duration(hours: 6);
const Duration _kLegacyRestoreEmptyBackoff = Duration(hours: 24);
const Set<String> _kAuthorityAccessStatuses = <String>{
  'active',
  'grace',
  'canceled',
};
const Set<String> _kReceiptAccessStatuses = <String>{
  ..._kAuthorityAccessStatuses,
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
  const _VerifiedSubscription({
    required this.expiry,
    required this.status,
    required this.providerAcknowledged,
  });

  final DateTime expiry;
  final String status;
  final bool providerAcknowledged;
}

class _PendingPurchase {
  _PendingPurchase({
    required this.productId,
    required this.userId,
    required this.completer,
  }) {
    completer.future.ignore();
  }

  final String productId;
  final String? userId;
  final Completer<SubscriptionState> completer;
}

class _PendingRestore {
  _PendingRestore({required this.userId}) {
    completer.future.ignore();
  }

  final String? userId;
  final Completer<SubscriptionState> completer = Completer<SubscriptionState>();
}

abstract class BillingClient {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<List<PurchaseDetails>> restorePurchases({String? applicationUserName});
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
  Future<List<PurchaseDetails>> restorePurchases({
    String? applicationUserName,
  }) async {
    final InAppPurchaseAndroidPlatformAddition addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final QueryPurchaseDetailsResponse response = await addition
        .queryPastPurchases(applicationUserName: applicationUserName);
    final IAPError? error = response.error;
    if (error != null) {
      throw InAppPurchaseException(
        source: error.source,
        code: error.code,
        message: error.message,
      );
    }
    return response.pastPurchases;
  }
}

class GooglePlayPaywallRepository
    implements IPaywallRepository, ISubscriptionAuthorityRefresher {
  GooglePlayPaywallRepository({
    BillingClient? billingClient,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
    http.Client? httpClient,
    bool? paywallTestingModeOverride,
    String? receiptVerifyEndpoint,
    SecureStore? secureStore,
    sb.SupabaseClient? supabaseClient,
    Duration authorityRequestTimeout = _kAuthorityRequestTimeout,
  }) : _billingClient = billingClient ?? InAppPurchaseBillingClient(),
       _sharedPreferencesLoader =
           sharedPreferencesLoader ?? SharedPreferences.getInstance,
       _httpClient = httpClient ?? http.Client(),
       _paywallTestingMode = paywallTestingModeOverride ?? paywallTestingMode,
       // Named public parameter intentionally maps to a private field.
       // ignore: prefer_initializing_formals
       _secureStore = secureStore,
       // Named public parameter intentionally maps to a private field.
       // ignore: prefer_initializing_formals
       _supabaseClient = supabaseClient,
       // Named public parameter intentionally maps to a private field.
       // ignore: prefer_initializing_formals
       _authorityRequestTimeout = authorityRequestTimeout,
       _receiptVerifyEndpoint =
           receiptVerifyEndpoint ?? Env.receiptVerifyEndpoint {
    _initialization = _loadPersistedState();
    _purchaseSub = _billingClient.purchaseStream.listen((
      List<PurchaseDetails> purchases,
    ) {
      unawaited(_enqueuePurchaseUpdate(purchases));
    }, onError: (Object error) => Logger.error('IAP stream error', error));
  }

  final BillingClient _billingClient;
  final Future<SharedPreferences> Function() _sharedPreferencesLoader;
  final http.Client _httpClient;
  final bool _paywallTestingMode;
  final SecureStore? _secureStore;
  final sb.SupabaseClient? _supabaseClient;
  final Duration _authorityRequestTimeout;
  final String _receiptVerifyEndpoint;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;
  late final Future<void> _initialization;

  SubscriptionState _state = const SubscriptionState(
    isActive: false,
    status: 'locked',
    source: 'google_play',
  );
  bool _hasAuthoritativeExpiry = false;
  bool _hasLegacyRestoreCandidate = false;
  bool _legacyRestoreAttempted = false;
  bool _legacyRestoreReady = false;
  bool _legacyRestoreInProgress = false;
  DateTime? _legacyRestoreNextRetryAt;
  String? _authorityStateUserId;
  String? _authorityRequestUserId;
  String? _authorityRefreshInFlightUserId;
  DateTime? _authorityVerifiedAt;
  int _authorityGeneration = 0;
  DateTime? _lastAuthorityRefreshAt;
  Future<SubscriptionState>? _authorityRefreshInFlight;
  bool _authorityRefreshInFlightWasForced = false;
  Future<SubscriptionState>? _restoreInFlight;
  String? _restoreInFlightUserId;
  Future<void> _purchaseUpdateQueue = Future<void>.value();
  bool _disposed = false;

  final Map<String, Future<SubscriptionState>> _purchaseStarts =
      <String, Future<SubscriptionState>>{};
  final Map<String, _PendingPurchase> _pendingPurchases =
      <String, _PendingPurchase>{};
  final Set<String> _approvalPending = <String>{};
  final Map<String, String> _pendingOwnerFingerprints = <String, String>{};
  _PendingRestore? _pendingRestore;

  static final Map<String, Future<void>> _persistenceQueues =
      <String, Future<void>>{};
  static final Map<String, int> _persistenceRevisions = <String, int>{};

  bool get _hasReceiptVerification {
    return parseSecureHttpsEndpoint(_receiptVerifyEndpoint) != null;
  }

  static const List<PaywallPlan> _plans = <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Monthly plan',
      priceLabel: 'Price unavailable',
      description: 'Monthly subscription billed through Google Play.',
      aiCreditsIncluded: 300,
      benefits: <String>[
        'Increases external-assistant credit allowance to 300 credits per month',
      ],
      isAvailable: false,
    ),
    PaywallPlan(
      id: 'annual',
      title: 'Annual plan',
      priceLabel: 'Price unavailable',
      description: 'Annual subscription billed through Google Play.',
      aiCreditsIncluded: 360,
      benefits: <String>[
        'Increases external-assistant credit allowance to 360 credits per month',
      ],
      isAvailable: false,
    ),
  ];

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    await _initialization;
    if (_paywallTestingMode) {
      return _plans
          .map(
            (PaywallPlan plan) => PaywallPlan(
              id: plan.id,
              title: plan.title,
              priceLabel: plan.priceLabel,
              description: plan.description,
              aiCreditsIncluded: plan.aiCreditsIncluded,
              benefits: plan.benefits,
              isAvailable: true,
            ),
          )
          .toList(growable: false);
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
          : 'External-assistant credit plans',
      body: _paywallTestingMode
          ? 'Premium gates are bypassed in this build.'
          : (billingReady
                ? 'Choose a plan to increase the monthly external-assistant credit allowance.'
                : 'Purchases are temporarily unavailable while billing verification is being finalized.'),
      plans: await getAvailablePlans(),
      isUnlocked: _paywallTestingMode || _effectiveStateForCurrentUser.isActive,
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
      isEntitled: _effectiveStateForCurrentUser.isActive,
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
    if (_effectiveStateForCurrentUser.isActive) {
      throw StateError(
        'Your current subscription is already active. Manage plan changes in Google Play.',
      );
    }
    final String? expectedUserId = _supabaseClient?.auth.currentUser?.id;
    if (_supabaseClient != null && expectedUserId == null) {
      throw StateError('Sign in before starting a subscription.');
    }

    final String? gpId = _kProductIds[planId];
    if (gpId == null) {
      throw ArgumentError('Unknown plan: $planId');
    }

    final String operationKey = _purchaseOperationKey(gpId, expectedUserId);
    final String? pendingOwner = await _pendingOwnerFingerprint(gpId);
    final String? expectedFingerprint = _billingAccountFingerprint(
      expectedUserId,
    );
    if (pendingOwner != null) {
      if (pendingOwner == expectedFingerprint) {
        return _purchasePendingState(planId);
      }
      throw StateError(
        'A pending Google Play purchase belongs to another signed-in account.',
      );
    }
    if (_approvalPending.contains(operationKey)) {
      return _purchasePendingState(planId);
    }
    final Future<SubscriptionState>? inFlight = _purchaseStarts[operationKey];
    if (inFlight != null) {
      return inFlight;
    }

    final Future<SubscriptionState> purchase = _startSubscriptionOnce(
      planId: planId,
      productId: gpId,
      expectedUserId: expectedUserId,
      operationKey: operationKey,
    );
    _purchaseStarts[operationKey] = purchase;
    try {
      return await purchase;
    } finally {
      if (identical(_purchaseStarts[operationKey], purchase)) {
        _purchaseStarts.remove(operationKey);
      }
    }
  }

  Future<SubscriptionState> _startSubscriptionOnce({
    required String planId,
    required String productId,
    required String? expectedUserId,
    required String operationKey,
  }) async {
    final ProductDetailsResponse response = await _billingClient
        .queryProductDetails(<String>{productId});
    if (response.productDetails.isEmpty) {
      throw StateError('Product $productId not found in Google Play.');
    }
    if (!_isCurrentBillingAccount(expectedUserId)) {
      throw StateError('The signed-in account changed during billing.');
    }

    final _PendingPurchase pending = _PendingPurchase(
      productId: productId,
      userId: expectedUserId,
      completer: Completer<SubscriptionState>(),
    );
    _pendingPurchases[operationKey] = pending;
    await _rememberPendingOwner(productId, expectedUserId);

    final PurchaseParam param = PurchaseParam(
      productDetails: response.productDetails.first,
      applicationUserName: _billingAccountFingerprint(expectedUserId),
    );
    late final bool purchaseStarted;
    try {
      purchaseStarted = await _billingClient.buyNonConsumable(
        purchaseParam: param,
      );
    } on Object {
      _removePendingPurchase(operationKey, pending);
      await _clearPendingOwner(productId, expectedUserId);
      rethrow;
    }
    if (!purchaseStarted) {
      _removePendingPurchase(operationKey, pending);
      await _clearPendingOwner(productId, expectedUserId);
      throw StateError('Google Play could not start the purchase.');
    }

    return pending.completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        _removePendingPurchase(operationKey, pending);
        throw TimeoutException('Purchase timed out.');
      },
    );
  }

  @override
  Future<SubscriptionState> cancelSubscription() async {
    await _initialization;
    if (!_paywallTestingMode && _supabaseClient?.auth.currentUser?.id != null) {
      return refreshSubscriptionState(force: true);
    }
    // Google Play cancellation normally disables renewal but keeps access
    // through the paid-through expiry. Without current server authority, the
    // client must preserve its existing trusted state instead of inventing an
    // immediate revocation.
    return _effectiveStateForCurrentUser;
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

    final String? currentUserId = _supabaseClient?.auth.currentUser?.id;
    final Future<SubscriptionState>? inFlight = _restoreInFlight;
    if (inFlight != null) {
      if (_restoreInFlightUserId != currentUserId) {
        throw StateError(
          'The signed-in account changed during purchase restore. Retry.',
        );
      }
      return inFlight;
    }
    final String? expectedUserId = currentUserId;
    if (_supabaseClient != null && expectedUserId == null) {
      throw StateError('Sign in before restoring purchases.');
    }
    final Future<SubscriptionState> restore = _restorePurchasesOnce(
      expectedUserId: expectedUserId,
    );
    _restoreInFlight = restore;
    _restoreInFlightUserId = expectedUserId;
    try {
      return await restore;
    } finally {
      if (identical(_restoreInFlight, restore)) {
        _restoreInFlight = null;
        _restoreInFlightUserId = null;
      }
    }
  }

  Future<SubscriptionState> _restorePurchasesOnce({
    required String? expectedUserId,
  }) async {
    final _PendingRestore pending = _PendingRestore(userId: expectedUserId);
    _pendingRestore = pending;
    try {
      final List<PurchaseDetails> pastPurchases = await _billingClient
          .restorePurchases(
            applicationUserName: _billingAccountFingerprint(expectedUserId),
          );
      if (pastPurchases.isNotEmpty) {
        await _enqueuePurchaseUpdate(pastPurchases);
      } else {
        // Test doubles and older billing adapters can still deliver through the
        // stream while restorePurchases completes. Flush that event turn
        // without guessing at a device-dependent delay.
        await Future<void>.delayed(Duration.zero);
      }
      if (pending.completer.isCompleted) {
        return await pending.completer.future;
      }
      if (!_isCurrentBillingAccount(expectedUserId)) {
        throw StateError(
          'The signed-in account changed during purchase restore. Retry.',
        );
      }

      if (_supabaseClient != null && expectedUserId != null) {
        final DateTime? verifiedBeforeRefresh = _authorityVerifiedAt;
        final SubscriptionState authority = await refreshSubscriptionState(
          force: true,
        );
        if (pending.completer.isCompleted) {
          return pending.completer.future;
        }
        final bool refreshedForExpectedAccount =
            _authorityStateUserId == expectedUserId &&
            _authorityVerifiedAt != verifiedBeforeRefresh;
        if (!refreshedForExpectedAccount) {
          return SubscriptionState(
            isActive: false,
            status: 'restore_error',
            source: authority.source,
          );
        }
        final SubscriptionState outcome = _restoreOutcome(authority);
        if (outcome.status == 'nothing_to_restore' && pastPurchases.isEmpty) {
          await _clearPendingOwnersForAccount(expectedUserId);
        }
        return outcome;
      }
      if (pastPurchases.isEmpty) {
        await _clearPendingOwnersForAccount(expectedUserId);
      }
      return const SubscriptionState(
        isActive: false,
        status: 'nothing_to_restore',
        source: 'google_play',
      );
    } finally {
      if (identical(_pendingRestore, pending)) {
        _pendingRestore = null;
      }
    }
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() async {
    await _initialization;
    return _effectiveStateForCurrentUser;
  }

  @override
  Future<SubscriptionState> refreshSubscriptionState({
    bool force = false,
  }) async {
    await _initialization;
    if (_paywallTestingMode) {
      return _effectiveStateForCurrentUser;
    }
    final sb.SupabaseClient? client = _supabaseClient;
    final String? userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return _effectiveStateForCurrentUser;
    }
    if (_authorityRequestUserId != userId) {
      _authorityRequestUserId = userId;
      _authorityGeneration += 1;
      _lastAuthorityRefreshAt = null;
    }
    final DateTime now = DateTime.now().toUtc();
    final DateTime? lastRefresh = _lastAuthorityRefreshAt;
    if (!force &&
        lastRefresh != null &&
        now.difference(lastRefresh) < _kAuthorityRefreshCooldown &&
        _authorityStateUserId == userId) {
      return _effectiveStateForCurrentUser;
    }

    final Future<SubscriptionState>? inFlight = _authorityRefreshInFlight;
    if (inFlight != null && _authorityRefreshInFlightUserId == userId) {
      if (!force || _authorityRefreshInFlightWasForced) {
        return inFlight;
      }
      _authorityGeneration += 1;
    }
    final int generation = _authorityGeneration;

    final Future<SubscriptionState> refresh = _refreshAuthority(
      client: client,
      expectedUserId: userId,
      generation: generation,
    );
    _lastAuthorityRefreshAt = now;
    _authorityRefreshInFlight = refresh;
    _authorityRefreshInFlightUserId = userId;
    _authorityRefreshInFlightWasForced = force;
    try {
      return await refresh;
    } finally {
      if (identical(_authorityRefreshInFlight, refresh)) {
        _authorityRefreshInFlight = null;
        _authorityRefreshInFlightUserId = null;
        _authorityRefreshInFlightWasForced = false;
      }
    }
  }

  @override
  bool get shouldRestoreLegacySubscription {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? nextRetryAt = _legacyRestoreNextRetryAt;
    return _legacyRestoreReady &&
        !_legacyRestoreAttempted &&
        !_legacyRestoreInProgress &&
        (nextRetryAt == null || !nextRetryAt.isAfter(now));
  }

  @override
  DateTime? get legacyRestoreNextRetryAt => _legacyRestoreNextRetryAt;

  @override
  Future<SubscriptionState?> restoreLegacySubscription() async {
    await _initialization;
    if (!shouldRestoreLegacySubscription) {
      return null;
    }
    final String? currentUserId = _supabaseClient?.auth.currentUser?.id;
    if (_supabaseClient != null && currentUserId == null) {
      return null;
    }
    _authorityStateUserId ??= currentUserId;
    _legacyRestoreInProgress = true;
    _legacyRestoreReady = false;
    try {
      final SubscriptionState restored = await restorePurchases();
      if (!restored.isActive) {
        _legacyRestoreNextRetryAt = DateTime.now().toUtc().add(
          _kLegacyRestoreEmptyBackoff,
        );
        await _persistState();
        return null;
      }
      _hasLegacyRestoreCandidate = false;
      _legacyRestoreAttempted = true;
      _legacyRestoreNextRetryAt = null;
      await _persistState();
      return refreshSubscriptionState(force: true);
    } on Object catch (error) {
      _legacyRestoreNextRetryAt = DateTime.now().toUtc().add(
        _kLegacyRestoreFailureBackoff,
      );
      await _persistState();
      Logger.warn('Legacy subscription restore failed: $error');
      return null;
    } finally {
      _legacyRestoreInProgress = false;
      _legacyRestoreReady = _hasLegacyRestoreCandidate;
    }
  }

  void dispose() {
    _disposed = true;
    _authorityGeneration += 1;
    _authorityRequestUserId = null;
    _purchaseSub.cancel();
  }

  Future<SubscriptionState> _refreshAuthority({
    required sb.SupabaseClient client,
    required String expectedUserId,
    required int generation,
  }) async {
    try {
      final List<dynamic> rows = await client
          .from('monetization_subscription_statuses')
          .select(
            'user_id,plan_id,product_id,status,is_active,expires_at,updated_at',
          )
          .eq('user_id', expectedUserId)
          .limit(1)
          .timeout(_authorityRequestTimeout);
      if (!_isCurrentAuthorityRequest(client, expectedUserId, generation)) {
        Logger.warn('Discarded subscription refresh after account change.');
        return _effectiveStateForCurrentUser;
      }

      final DateTime now = DateTime.now().toUtc();
      _authorityVerifiedAt = now;
      _authorityStateUserId = expectedUserId;
      if (rows.isEmpty) {
        _legacyRestoreReady =
            _hasLegacyRestoreCandidate && !_legacyRestoreAttempted;
        _state = const SubscriptionState(
          isActive: false,
          status: 'free',
          source: 'supabase_authority',
        );
        _hasAuthoritativeExpiry = false;
        await _persistState();
        return _isCurrentAuthorityRequest(client, expectedUserId, generation)
            ? _state
            : _effectiveStateForCurrentUser;
      }

      final Object? rawRow = rows.first;
      if (rawRow is! Map) {
        return _lockAuthority(
          expectedUserId: expectedUserId,
          generation: generation,
          status: 'authority_invalid',
        );
      }
      final Map<String, dynamic> row = rawRow.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      final String? productId = row['product_id']?.toString();
      String? planId;
      for (final MapEntry<String, String> entry in _kProductIds.entries) {
        if (entry.value == productId) {
          planId = entry.key;
          break;
        }
      }
      final String status = row['status']?.toString() ?? '';
      final DateTime? expiry = DateTime.tryParse(
        row['expires_at']?.toString() ?? '',
      )?.toUtc();
      final DateTime? updatedAt = DateTime.tryParse(
        row['updated_at']?.toString() ?? '',
      )?.toUtc();
      final bool shapeIsValid =
          row['user_id']?.toString() == expectedUserId &&
          planId != null &&
          row['plan_id']?.toString() == _kServerPlanIds[planId] &&
          status.isNotEmpty &&
          updatedAt != null &&
          !updatedAt.isAfter(now.add(_kAuthorityFutureClockSkew)) &&
          (expiry == null || _isExpiryWithinMaximum(expiry, now));
      if (!shapeIsValid) {
        return _lockAuthority(
          expectedUserId: expectedUserId,
          generation: generation,
          status: 'authority_invalid',
        );
      }

      final bool isActive =
          row['is_active'] == true &&
          _kAuthorityAccessStatuses.contains(status) &&
          expiry != null &&
          expiry.isAfter(now);
      if (!_isCurrentAuthorityRequest(client, expectedUserId, generation)) {
        return _effectiveStateForCurrentUser;
      }
      _state = SubscriptionState(
        isActive: isActive,
        status: isActive
            ? status
            : (expiry != null && !expiry.isAfter(now) ? 'expired' : status),
        source: 'supabase_authority',
        planId: planId,
        renewalDate: expiry,
      );
      _hasAuthoritativeExpiry = isActive;
      _hasLegacyRestoreCandidate = false;
      _legacyRestoreReady = false;
      await _persistState();
      return _isCurrentAuthorityRequest(client, expectedUserId, generation)
          ? _state
          : _effectiveStateForCurrentUser;
    } on Object catch (error) {
      Logger.warn('Subscription authority refresh failed: $error');
      if (!_isCurrentAuthorityRequest(client, expectedUserId, generation)) {
        return _effectiveStateForCurrentUser;
      }
      final bool isTransient = _isTransientAuthorityFailure(error);
      if (isTransient && _hasValidOfflineLease(expectedUserId)) {
        return _effectiveStateForCurrentUser;
      }
      return _lockAuthority(
        expectedUserId: expectedUserId,
        generation: generation,
        status: 'authority_unavailable',
        preserveLegacyCandidate: isTransient,
      );
    }
  }

  Future<SubscriptionState> _lockAuthority({
    required String expectedUserId,
    required int generation,
    required String status,
    bool preserveLegacyCandidate = false,
  }) async {
    final sb.SupabaseClient? client = _supabaseClient;
    if (client == null ||
        !_isCurrentAuthorityRequest(client, expectedUserId, generation)) {
      return _effectiveStateForCurrentUser;
    }
    _state = const SubscriptionState(
      isActive: false,
      status: 'authority_invalid',
      source: 'supabase_authority',
    );
    if (status != 'authority_invalid') {
      _state = SubscriptionState(
        isActive: false,
        status: status,
        source: 'supabase_authority',
      );
    }
    _hasAuthoritativeExpiry = false;
    _authorityStateUserId = expectedUserId;
    _authorityVerifiedAt = DateTime.now().toUtc();
    if (!preserveLegacyCandidate) {
      _hasLegacyRestoreCandidate = false;
    }
    _legacyRestoreReady = false;
    await _persistState();
    return _isCurrentAuthorityRequest(client, expectedUserId, generation)
        ? _state
        : _effectiveStateForCurrentUser;
  }

  Future<void> _enqueuePurchaseUpdate(List<PurchaseDetails> purchases) {
    final Future<void> queued = _purchaseUpdateQueue
        .catchError((Object _) {})
        .then((_) => _onPurchaseUpdate(purchases));
    _purchaseUpdateQueue = queued;
    return queued.catchError((Object error, StackTrace stackTrace) {
      Logger.error('Google Play purchase update failed: $error\n$stackTrace');
    });
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    await _initialization;
    for (final PurchaseDetails purchase in purchases) {
      if (_disposed) {
        return;
      }

      final String? currentUserId = _supabaseClient?.auth.currentUser?.id;
      final String? currentFingerprint = _billingAccountFingerprint(
        currentUserId,
      );
      final String? persistedOwner = await _pendingOwnerFingerprint(
        purchase.productID,
      );
      final bool discardedForAccountChange =
          _failPendingPurchasesForOtherAccounts(
            productId: purchase.productID,
            currentUserId: currentUserId,
          );
      final String operationKey = _purchaseOperationKey(
        purchase.productID,
        currentUserId,
      );
      final _PendingPurchase? pending = _pendingPurchases[operationKey];
      final _PendingRestore? restore = _pendingRestore;
      if (!_isCurrentBillingAccount(currentUserId)) {
        final StateError error = StateError(
          'Sign in before Google Play purchase verification can continue.',
        );
        _completePendingPurchaseError(pending, error);
        _completePendingRestoreError(restore, error);
        _removePendingPurchase(operationKey, pending);
        Logger.warn(
          'Google Play update left unacknowledged until an account is signed in.',
        );
        continue;
      }
      if (persistedOwner != null && persistedOwner != currentFingerprint) {
        final StateError error = StateError(
          'This Google Play purchase belongs to another signed-in account.',
        );
        _completePendingPurchaseError(pending, error);
        _completePendingRestoreError(restore, error);
        _removePendingPurchase(operationKey, pending);
        Logger.warn(
          'Google Play update left unacknowledged because its pending owner changed.',
        );
        continue;
      }
      if (restore != null && restore.userId != currentUserId) {
        _completePendingRestoreError(
          restore,
          StateError('The signed-in account changed during purchase restore.'),
        );
        Logger.warn(
          'Google Play restore update left unacknowledged after an account change.',
        );
        continue;
      }
      if (discardedForAccountChange && pending == null) {
        Logger.warn(
          'Google Play purchase update left unacknowledged after an account change.',
        );
        continue;
      }
      final bool hasTrustedOwner =
          _supabaseClient == null ||
          pending?.userId == currentUserId ||
          restore?.userId == currentUserId ||
          (persistedOwner != null && persistedOwner == currentFingerprint);
      if (!hasTrustedOwner) {
        Logger.warn(
          'Unscoped Google Play update left unacknowledged until explicit restore.',
        );
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final String? expectedUserId =
            pending?.userId ?? restore?.userId ?? currentUserId;
        final _VerifiedSubscription? verification =
            await _verifiedSubscriptionFromServer(
              purchase,
              expectedUserId: expectedUserId,
            );
        final String? planId = _planIdForProduct(purchase.productID);
        final bool accountIsCurrent = _isCurrentBillingAccount(expectedUserId);
        if (verification != null && planId != null && accountIsCurrent) {
          bool acknowledged =
              verification.providerAcknowledged ||
              !purchase.pendingCompletePurchase;
          if (purchase.pendingCompletePurchase) {
            try {
              await _billingClient.completePurchase(purchase);
              acknowledged = true;
            } on Object catch (error) {
              if (!verification.providerAcknowledged) {
                final SubscriptionState failed = _transactionOutcomeState(
                  status: 'acknowledgement_failed',
                  attemptedPlanId: planId,
                );
                _completePendingPurchase(pending, failed);
                _completePendingRestore(restore, failed);
                _removePendingPurchase(operationKey, pending);
                Logger.warn(
                  'Verified purchase remains pending because acknowledgement failed: $error',
                );
                continue;
              }
              Logger.warn(
                'Local purchase completion failed after server acknowledgement: $error',
              );
            }
          }
          if (!acknowledged) {
            final SubscriptionState failed = _transactionOutcomeState(
              status: 'acknowledgement_failed',
              attemptedPlanId: planId,
            );
            _completePendingPurchase(pending, failed);
            _completePendingRestore(restore, failed);
            _removePendingPurchase(operationKey, pending);
            continue;
          }
          if (!_isCurrentBillingAccount(expectedUserId)) {
            final StateError error = StateError(
              'The signed-in account changed during purchase acknowledgement.',
            );
            _completePendingPurchaseError(pending, error);
            _completePendingRestoreError(restore, error);
            _removePendingPurchase(operationKey, pending);
            continue;
          }
          _state = SubscriptionState(
            isActive: true,
            status: verification.status,
            source: 'google_play',
            planId: planId,
            renewalDate: verification.expiry,
          );
          _hasAuthoritativeExpiry = true;
          _authorityStateUserId = expectedUserId;
          _authorityVerifiedAt = DateTime.now().toUtc();
          _hasLegacyRestoreCandidate = false;
          _legacyRestoreReady = false;
          await _persistState();
          if (!_isCurrentBillingAccount(expectedUserId)) {
            final StateError error = StateError(
              'The signed-in account changed during purchase verification.',
            );
            _completePendingPurchaseError(pending, error);
            _completePendingRestoreError(restore, error);
            _removePendingPurchase(operationKey, pending);
            Logger.warn(
              'Verified Google Play update left unacknowledged after an account change.',
            );
            continue;
          }
          _completePendingPurchase(pending, _state);
          _completePendingRestore(restore, _restoreOutcome(_state));
          _approvalPending.remove(operationKey);
          await _clearPendingOwner(purchase.productID, expectedUserId);
        } else {
          if (!accountIsCurrent) {
            final StateError error = StateError(
              'The signed-in account changed during purchase verification.',
            );
            _completePendingPurchaseError(pending, error);
            _completePendingRestoreError(restore, error);
            _removePendingPurchase(operationKey, pending);
            continue;
          }
          final SubscriptionState failed = _transactionOutcomeState(
            status: 'verification_failed',
            attemptedPlanId: planId,
          );
          _completePendingPurchase(pending, failed);
          _completePendingRestore(restore, failed);
          Logger.warn(
            'Google Play update left unacknowledged for server verification retry.',
          );
        }
        _removePendingPurchase(operationKey, pending);
      } else if (purchase.status == PurchaseStatus.error) {
        Logger.error('IAP purchase error', purchase.error);
        _completePendingPurchaseError(
          pending,
          purchase.error ?? StateError('Purchase failed.'),
        );
        _completePendingRestore(
          restore,
          const SubscriptionState(
            isActive: false,
            status: 'restore_error',
            source: 'google_play',
          ),
        );
        _approvalPending.remove(operationKey);
        _removePendingPurchase(operationKey, pending);
        await _clearPendingOwner(purchase.productID, currentUserId);
      } else if (purchase.status == PurchaseStatus.canceled) {
        final SubscriptionState canceled = _transactionOutcomeState(
          status: 'purchase_canceled',
          attemptedPlanId: _planIdForProduct(purchase.productID),
        );
        _completePendingPurchase(pending, canceled);
        _completePendingRestore(restore, _restoreOutcome(canceled));
        _approvalPending.remove(operationKey);
        _removePendingPurchase(operationKey, pending);
        await _clearPendingOwner(purchase.productID, currentUserId);
      } else if (purchase.status == PurchaseStatus.pending) {
        final String? planId = _planIdForProduct(purchase.productID);
        final SubscriptionState purchasePending = _purchasePendingState(planId);
        await _rememberPendingOwner(purchase.productID, currentUserId);
        _approvalPending.add(operationKey);
        _completePendingPurchase(pending, purchasePending);
        _completePendingRestore(restore, purchasePending);
        _removePendingPurchase(operationKey, pending);
        Logger.log('IAP', 'Purchase is pending external approval.');
      }
    }
  }

  String _purchaseOperationKey(String productId, String? userId) {
    return '${userId ?? '__unscoped__'}::$productId';
  }

  String? _billingAccountFingerprint(String? userId) {
    final String normalized = userId?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  String _pendingOwnerStorageKey(String productId) {
    return '${AccountDataRegistry.pendingPurchaseOwnerSecureKeyPrefix}'
        '$productId';
  }

  Future<String?> _pendingOwnerFingerprint(String productId) async {
    final String? cached = _pendingOwnerFingerprints[productId];
    if (cached != null) {
      return cached;
    }
    final SecureStore? secureStore = _secureStore;
    if (secureStore == null) {
      return null;
    }
    final String? persisted = await secureStore.readString(
      _pendingOwnerStorageKey(productId),
    );
    if (persisted != null && persisted.isNotEmpty) {
      _pendingOwnerFingerprints[productId] = persisted;
    }
    return persisted;
  }

  Future<void> _rememberPendingOwner(String productId, String? userId) async {
    final String? fingerprint = _billingAccountFingerprint(userId);
    if (fingerprint == null) {
      return;
    }
    _pendingOwnerFingerprints[productId] = fingerprint;
    final SecureStore? secureStore = _secureStore;
    if (secureStore == null) {
      if (Env.isProduction) {
        _pendingOwnerFingerprints.remove(productId);
        throw StateError(
          'Secure billing state is unavailable. Purchase was not started.',
        );
      }
      return;
    }
    await secureStore.writeString(
      _pendingOwnerStorageKey(productId),
      fingerprint,
    );
  }

  Future<void> _clearPendingOwner(String productId, String? userId) async {
    final String? expected = _billingAccountFingerprint(userId);
    final String? stored = await _pendingOwnerFingerprint(productId);
    if (stored == null || (expected != null && stored != expected)) {
      return;
    }
    final SecureStore? secureStore = _secureStore;
    if (secureStore != null) {
      await secureStore.delete(_pendingOwnerStorageKey(productId));
    }
    _pendingOwnerFingerprints.remove(productId);
  }

  Future<void> _clearPendingOwnersForAccount(String? userId) async {
    for (final String productId in _kProductIds.values) {
      await _clearPendingOwner(productId, userId);
    }
  }

  bool _isCurrentBillingAccount(String? expectedUserId) {
    final sb.SupabaseClient? client = _supabaseClient;
    return client == null ||
        (expectedUserId != null &&
            client.auth.currentUser?.id == expectedUserId);
  }

  String? _planIdForProduct(String productId) {
    for (final MapEntry<String, String> entry in _kProductIds.entries) {
      if (entry.value == productId) {
        return entry.key;
      }
    }
    return null;
  }

  SubscriptionState _purchasePendingState(String? planId) {
    return _transactionOutcomeState(
      status: 'purchase_pending',
      attemptedPlanId: planId,
    );
  }

  SubscriptionState _transactionOutcomeState({
    required String status,
    required String? attemptedPlanId,
  }) {
    final SubscriptionState existing = _effectiveStateForCurrentUser;
    return SubscriptionState(
      isActive: existing.isActive,
      status: status,
      source: 'google_play',
      planId: existing.isActive ? existing.planId : attemptedPlanId,
      renewalDate: existing.isActive ? existing.renewalDate : null,
      isTesting: existing.isActive && existing.isTesting,
    );
  }

  SubscriptionState _restoreOutcome(SubscriptionState state) {
    if (state.status == 'purchase_pending' ||
        state.status == 'verification_failed' ||
        state.status == 'acknowledgement_failed' ||
        state.status == 'restore_error' ||
        state.status == 'nothing_to_restore') {
      return state;
    }
    if (state.isActive) {
      return SubscriptionState(
        isActive: true,
        status: 'restored_active',
        source: state.source,
        planId: state.planId,
        renewalDate: state.renewalDate,
        isTesting: state.isTesting,
      );
    }
    if (state.status == 'authority_unavailable' ||
        state.status == 'authority_invalid' ||
        state.status == 'authority_stale' ||
        state.status == 'account_changed' ||
        state.status == 'purchase_canceled' ||
        state.status == 'purchase_cancelled') {
      return SubscriptionState(
        isActive: false,
        status: 'restore_error',
        source: state.source,
      );
    }
    return SubscriptionState(
      isActive: false,
      status: 'nothing_to_restore',
      source: state.source,
    );
  }

  bool _failPendingPurchasesForOtherAccounts({
    required String productId,
    required String? currentUserId,
  }) {
    final List<MapEntry<String, _PendingPurchase>> stale = _pendingPurchases
        .entries
        .where(
          (MapEntry<String, _PendingPurchase> entry) =>
              entry.value.productId == productId &&
              entry.value.userId != currentUserId,
        )
        .toList(growable: false);
    for (final MapEntry<String, _PendingPurchase> entry in stale) {
      _completePendingPurchaseError(
        entry.value,
        StateError('The signed-in account changed during billing.'),
      );
      _removePendingPurchase(entry.key, entry.value);
    }
    return stale.isNotEmpty;
  }

  void _removePendingPurchase(String operationKey, _PendingPurchase? pending) {
    if (pending != null &&
        identical(_pendingPurchases[operationKey], pending)) {
      _pendingPurchases.remove(operationKey);
    }
  }

  void _completePendingPurchase(
    _PendingPurchase? pending,
    SubscriptionState state,
  ) {
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(state);
    }
  }

  void _completePendingPurchaseError(_PendingPurchase? pending, Object error) {
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.completeError(error);
    }
  }

  void _completePendingRestore(
    _PendingRestore? pending,
    SubscriptionState state,
  ) {
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(state);
    }
  }

  void _completePendingRestoreError(_PendingRestore? pending, Object error) {
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.completeError(error);
    }
  }

  Future<_VerifiedSubscription?> _verifiedSubscriptionFromServer(
    PurchaseDetails purchase, {
    required String? expectedUserId,
  }) async {
    if (!_hasReceiptVerification) {
      Logger.error(
        'Receipt verification is unavailable; purchase remains locked.',
      );
      return null;
    }
    final Uri endpoint = parseSecureHttpsEndpoint(_receiptVerifyEndpoint)!;
    if (expectedUserId != null &&
        _supabaseClient?.auth.currentUser?.id != expectedUserId) {
      return null;
    }
    final String? accessToken =
        _supabaseClient?.auth.currentSession?.accessToken ??
        currentSupabaseAccessToken();
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
      if (expectedUserId != null &&
          _supabaseClient?.auth.currentUser?.id != expectedUserId) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        Logger.error('Receipt verification returned a non-object payload.');
        return null;
      }
      final Map<String, dynamic> body = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      if (body['valid'] != true) {
        return null;
      }
      if (body['productId'] != purchase.productID) {
        Logger.error('Receipt verification returned a mismatched product.');
        return null;
      }
      final Object? rawStatus = body['status'];
      if (rawStatus is! String ||
          !_kReceiptAccessStatuses.contains(rawStatus)) {
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
      final DateTime now = DateTime.now().toUtc();
      if (!expiry.isAfter(now) || !_isExpiryWithinMaximum(expiry, now)) {
        Logger.error('Receipt verification returned an invalid expiry.');
        return null;
      }
      return _VerifiedSubscription(
        expiry: expiry,
        status: rawStatus,
        providerAcknowledged: body['acknowledged'] == true,
      );
    } on Object catch (error) {
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
    final DateTime now = DateTime.now().toUtc();
    final DateTime? expiry = _state.renewalDate;
    if (!_hasAuthoritativeExpiry ||
        expiry == null ||
        !expiry.isAfter(now) ||
        !_isExpiryWithinMaximum(expiry, now)) {
      return false;
    }
    final sb.SupabaseClient? client = _supabaseClient;
    if (client == null) {
      return true;
    }
    return _authorityStateUserId == client.auth.currentUser?.id &&
        _hasCurrentAuthorityLease(now);
  }

  SubscriptionState get _effectiveStateForCurrentUser {
    final String? currentUserId = _supabaseClient?.auth.currentUser?.id;
    if (!_paywallTestingMode &&
        _supabaseClient != null &&
        _hasAuthoritativeExpiry &&
        (_authorityStateUserId == null ||
            _authorityStateUserId != currentUserId)) {
      return const SubscriptionState(
        isActive: false,
        status: 'account_changed',
        source: 'supabase_authority',
      );
    }
    if (_isSubscriptionActive) {
      final DateTime? leaseUntil = _authorityLeaseUntil;
      final DateTime? renewalDate = _state.renewalDate;
      if (_supabaseClient != null &&
          leaseUntil != null &&
          renewalDate != null &&
          leaseUntil.isBefore(renewalDate)) {
        return SubscriptionState(
          isActive: true,
          status: _state.status,
          source: _state.source,
          planId: _state.planId,
          renewalDate: leaseUntil,
          isTesting: _state.isTesting,
        );
      }
      return _state;
    }
    if (!_state.isActive) {
      return _state;
    }
    final DateTime now = DateTime.now().toUtc();
    final DateTime? expiry = _state.renewalDate;
    final bool authorityStale =
        _supabaseClient != null &&
        (expiry == null || expiry.isAfter(now)) &&
        !_hasCurrentAuthorityLease(now);
    return SubscriptionState(
      isActive: false,
      status: authorityStale ? 'authority_stale' : 'expired',
      source: _state.source,
      planId: _state.planId,
      renewalDate: _state.renewalDate,
      isTesting: _state.isTesting,
    );
  }

  bool _isCurrentAuthorityRequest(
    sb.SupabaseClient client,
    String expectedUserId,
    int generation,
  ) {
    return client.auth.currentUser?.id == expectedUserId &&
        !_disposed &&
        _authorityRequestUserId == expectedUserId &&
        _authorityGeneration == generation;
  }

  bool _isTransientAuthorityFailure(Object error) {
    if (error is TimeoutException || error is http.ClientException) {
      return true;
    }
    if (error is sb.PostgrestException) {
      final int? statusCode = int.tryParse(error.code ?? '');
      if (statusCode == 408 ||
          statusCode == 429 ||
          (statusCode != null && statusCode >= 500 && statusCode <= 599)) {
        return true;
      }
      final String code = (error.code ?? '').toUpperCase();
      return code.startsWith('08') ||
          code.startsWith('53') ||
          code == '57P01' ||
          code.startsWith('58') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003';
    }
    return false;
  }

  bool _hasValidOfflineLease(String expectedUserId) {
    return _authorityStateUserId == expectedUserId &&
        _hasCurrentAuthorityLease(DateTime.now().toUtc()) &&
        _isSubscriptionActive;
  }

  DateTime? get _authorityLeaseUntil {
    return _authorityVerifiedAt?.add(_kAuthorityOfflineLease);
  }

  bool _hasCurrentAuthorityLease(DateTime now) {
    final DateTime? verifiedAt = _authorityVerifiedAt;
    final DateTime? leaseUntil = _authorityLeaseUntil;
    return verifiedAt != null &&
        leaseUntil != null &&
        !verifiedAt.isAfter(now.add(_kAuthorityFutureClockSkew)) &&
        leaseUntil.isAfter(now);
  }

  bool _isExpiryWithinMaximum(DateTime expiry, DateTime now) {
    return !expiry.isAfter(now.add(_kMaximumAuthorityExpiry));
  }

  Future<void> _loadPersistedState() async {
    try {
      final SharedPreferences prefs = await _sharedPreferencesLoader();
      final String currentUserId =
          _supabaseClient?.auth.currentUser?.id.trim() ?? '';
      if (currentUserId.isEmpty) {
        // Persisted entitlement is account-owned. Without a current identity,
        // loading any legacy/global value could grant another user's state.
        return;
      }
      final String? trustedLegacyOwnerId = await _secureStore?.readString(
        _kLegacyEntitlementOwnerKey,
      );
      final String accountKey = _stateStorageKey(currentUserId);
      final bool mayReadLegacy = trustedLegacyOwnerId?.trim() == currentUserId;
      final List<String> candidateKeys = <String>[
        accountKey,
        if (mayReadLegacy) _kPrefsKey,
      ];
      if (_secureStore == null) {
        if (Env.isProduction) {
          Logger.error(
            'Secure storage is unavailable in production; using locked paywall state.',
          );
          return;
        }
        String? fallbackRaw;
        for (final String key in candidateKeys) {
          fallbackRaw = prefs.getString(key);
          if (fallbackRaw != null) {
            break;
          }
        }
        if (fallbackRaw != null) {
          _applyPersistedState(
            fallbackRaw,
            trustedLegacyOwnerId: trustedLegacyOwnerId,
          );
        }
        return;
      }

      String? raw;
      for (final String key in candidateKeys) {
        raw = await _secureStore.readString(key);
        if (raw != null) {
          break;
        }
        raw = prefs.getString(key);
        if (raw != null) {
          break;
        }
      }
      if (raw == null) {
        return;
      }
      _applyPersistedState(raw, trustedLegacyOwnerId: trustedLegacyOwnerId);
    } on Exception catch (error) {
      Logger.error('Failed to load persisted subscription state', error);
    }
  }

  void _applyPersistedState(
    String raw, {
    required String? trustedLegacyOwnerId,
  }) {
    final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
    final DateTime now = DateTime.now().toUtc();
    final DateTime? parsedRenewal = DateTime.tryParse(
      map['renewalDate']?.toString() ?? '',
    );
    final DateTime? renewal =
        parsedRenewal != null &&
            !parsedRenewal.isAfter(now.add(_kMaximumAuthorityExpiry))
        ? parsedRenewal
        : null;
    _hasAuthoritativeExpiry = map['expirySource'] == 'google_play_server';
    _authorityStateUserId = map['authorityUserId']?.toString();
    _authorityVerifiedAt = DateTime.tryParse(
      map['authorityVerifiedAt']?.toString() ?? '',
    )?.toUtc();
    _legacyRestoreAttempted = map['legacyRestoreAttempted'] == true;
    _legacyRestoreNextRetryAt = DateTime.tryParse(
      map['legacyRestoreNextRetryAt']?.toString() ?? '',
    )?.toUtc();
    final bool candidateRequested =
        map['legacyRestoreCandidate'] == true ||
        (map['isActive'] == true &&
            !_hasAuthoritativeExpiry &&
            !_legacyRestoreAttempted);
    final String? currentUserId = _supabaseClient?.auth.currentUser?.id;
    final String? candidateOwnerId =
        _authorityStateUserId ?? trustedLegacyOwnerId;
    _hasLegacyRestoreCandidate =
        candidateRequested &&
        currentUserId != null &&
        candidateOwnerId == currentUserId;
    _legacyRestoreReady =
        _hasLegacyRestoreCandidate && !_legacyRestoreAttempted;
    final bool isActive =
        map['isActive'] == true &&
        _hasAuthoritativeExpiry &&
        renewal != null &&
        renewal.isAfter(now);
    _state = SubscriptionState(
      isActive: isActive,
      status: map['status'] as String? ?? 'locked',
      source: 'google_play',
      planId: map['planId'] as String?,
      renewalDate: renewal,
    );
  }

  String _stateStorageKey(String? userId) {
    final String accountId = userId?.trim() ?? '';
    return accountId.isEmpty ? _kPrefsKey : '$_kPrefsKey.account.$accountId';
  }

  Future<void> _persistState() async {
    final String storageKey = _stateStorageKey(_authorityStateUserId);
    final String encoded = jsonEncode(<String, dynamic>{
      'isActive': _state.isActive,
      'status': _state.status,
      'planId': _state.planId,
      'renewalDate': _state.renewalDate?.toIso8601String(),
      'expirySource': _hasAuthoritativeExpiry ? 'google_play_server' : null,
      'authorityUserId': _authorityStateUserId,
      'authorityVerifiedAt': _authorityVerifiedAt?.toIso8601String(),
      'legacyRestoreCandidate': _hasLegacyRestoreCandidate,
      'legacyRestoreAttempted': _legacyRestoreAttempted,
      'legacyRestoreNextRetryAt': _legacyRestoreNextRetryAt?.toIso8601String(),
    });
    final int revision = (_persistenceRevisions[storageKey] ?? 0) + 1;
    _persistenceRevisions[storageKey] = revision;
    final Future<void> previous =
        _persistenceQueues[storageKey] ?? Future<void>.value();
    late final Future<void> queued;
    queued = previous.catchError((Object _) {}).then((_) async {
      if (_persistenceRevisions[storageKey] != revision) {
        return;
      }
      await _writePersistedState(storageKey, encoded);
    });
    _persistenceQueues[storageKey] = queued;
    try {
      await queued;
    } on Exception catch (error) {
      Logger.error('Failed to persist subscription state', error);
    } finally {
      if (identical(_persistenceQueues[storageKey], queued)) {
        _persistenceQueues.remove(storageKey);
        _persistenceRevisions.remove(storageKey);
      }
    }
  }

  Future<void> _writePersistedState(String storageKey, String encoded) async {
    try {
      if (_secureStore == null) {
        if (Env.isProduction) {
          Logger.error(
            'Secure storage is unavailable in production; paywall state was not persisted.',
          );
          return;
        }
        final SharedPreferences prefs = await _sharedPreferencesLoader();
        await prefs.setString(storageKey, encoded);
        return;
      }
      await _secureStore.writeString(storageKey, encoded);
    } on Exception catch (error) {
      Logger.error('Failed to persist subscription state', error);
      rethrow;
    }
  }
}
