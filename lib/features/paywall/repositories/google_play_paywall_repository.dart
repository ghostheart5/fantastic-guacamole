import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/config/paywall_config.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/domain/entities/entitlement.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_entity.dart';
import 'package:fantastic_guacamole/domain/entities/paywall_plan.dart';
import 'package:fantastic_guacamole/domain/entities/subscription_state.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_paywall_repository.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Google Play subscription product IDs — must match Play Console registration.
const _kProductIds = <String, String>{
  'monthly': 'chronospark_premium_monthly',
  'annual': 'chronospark_premium_annual',
};
const _kPrefsKey = 'paywall_subscription_state_v1';
const _kPackageName = 'com.ghostheart5.chronospark';

class GooglePlayPaywallRepository implements IPaywallRepository {
  GooglePlayPaywallRepository() {
    _iap = InAppPurchase.instance;
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => Logger.error('IAP stream error', e),
    );
    _loadPersistedState();
  }

  late final InAppPurchase _iap;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSub;

  SubscriptionState _state = const SubscriptionState(
    isActive: false,
    status: 'locked',
    source: 'google_play',
  );

  // Pending completers waiting for the IAP stream to resolve a purchase.
  final Map<String, Completer<SubscriptionState>> _pending = {};

  static const List<PaywallPlan> _plans = <PaywallPlan>[
    PaywallPlan(
      id: 'monthly',
      title: 'Premium Monthly',
      priceLabel: 'from \$9.99 / month',
      description:
          'Best for active users who want full AI coaching and recurring credits.',
      aiCreditsIncluded: 300,
      benefits: <String>[
        '300 AI credits every month',
        'Priority AI responses',
        'Advanced memory and insights',
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
        '360 AI credits every month',
        'Yearly billing discount',
        'Unlimited access to premium tools',
      ],
    ),
  ];

  // ── public interface ────────────────────────────────────────────────────────

  @override
  Future<List<PaywallPlan>> getAvailablePlans() async {
    if (paywallTestingMode) return _plans;
    try {
      final Set<String> ids = _kProductIds.values.toSet();
      final ProductDetailsResponse res = await _iap.queryProductDetails(ids);
      if (res.error != null || res.productDetails.isEmpty) {
        return _plans; // fall back to static labels
      }
      return _plans.map((PaywallPlan plan) {
        final String? gpId = _kProductIds[plan.id];
        final ProductDetails? detail = res.productDetails
            .where((d) => d.id == gpId)
            .firstOrNull;
        return PaywallPlan(
          id: plan.id,
          title: plan.title,
          priceLabel: detail?.price ?? plan.priceLabel,
          description: plan.description,
          aiCreditsIncluded: plan.aiCreditsIncluded,
          benefits: plan.benefits,
          isAvailable: detail != null,
          isFeatured: plan.isFeatured,
        );
      }).toList(growable: false);
    } on Exception catch (e) {
      Logger.error('getAvailablePlans failed', e);
      return _plans;
    }
  }

  @override
  Future<PaywallEntity> getPaywallConfig() async {
    return PaywallEntity(
      featureId: 'premium',
      title: paywallTestingMode ? 'Unlocked for testing' : 'AI Credits + Premium',
      body: paywallTestingMode
          ? 'Premium gates are bypassed in this build.'
          : 'Unlock AI credits, premium coaching, deeper memory, and advanced tools.',
      plans: await getAvailablePlans(),
      isUnlocked: paywallTestingMode || _state.isActive,
    );
  }

  @override
  Future<Entitlement> checkEntitlement({String? featureId}) async {
    if (paywallTestingMode) {
      return Entitlement(
        featureId: featureId ?? 'premium',
        isEntitled: true,
        source: 'testing_mode',
      );
    }
    return Entitlement(
      featureId: featureId ?? 'premium',
      isEntitled: _state.isActive,
      source: _state.source,
      expiresAt: _state.renewalDate,
    );
  }

  @override
  Future<SubscriptionState> startSubscription(String planId) async {
    if (paywallTestingMode) {
      _state = SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        planId: planId,
        renewalDate: DateTime.now().add(const Duration(days: 30)),
        isTesting: true,
      );
      return _state;
    }

    final String? gpId = _kProductIds[planId];
    if (gpId == null) {
      throw ArgumentError('Unknown plan: $planId');
    }

    // Query product details first so we have a valid PurchaseParam.
    final ProductDetailsResponse res = await _iap.queryProductDetails({gpId});
    if (res.productDetails.isEmpty) {
      throw StateError('Product $gpId not found in Google Play.');
    }

    final Completer<SubscriptionState> completer = Completer();
    _pending[gpId] = completer;

    final PurchaseParam param = PurchaseParam(
      productDetails: res.productDetails.first,
    );
    await _iap.buyNonConsumable(purchaseParam: param);

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
    // Google Play subscriptions are cancelled by the user in Play Store;
    // we just update local state to reflect the cancellation.
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
    if (paywallTestingMode) {
      _state = SubscriptionState(
        isActive: true,
        status: 'unlocked_for_testing',
        source: 'testing_mode',
        planId: _state.planId ?? 'annual',
        renewalDate: DateTime.now().add(const Duration(days: 30)),
        isTesting: true,
      );
      return _state;
    }

    final Completer<SubscriptionState> completer = Completer();
    _pending['__restore__'] = completer;
    await _iap.restorePurchases();

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pending.remove('__restore__');
        return _state; // no active sub found — return current (locked) state
      },
    );
  }

  @override
  Future<SubscriptionState> getUserSubscriptionState() async {
    return _state;
  }

  void dispose() => _purchaseSub.cancel();

  // ── private helpers ─────────────────────────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final bool verified = await _verifyWithServer(purchase);
        if (verified) {
          final String planId = _kProductIds.entries
              .firstWhere(
                (e) => e.value == purchase.productID,
                orElse: () => const MapEntry('monthly', ''),
              )
              .key;
          _state = SubscriptionState(
            isActive: true,
            status: purchase.status == PurchaseStatus.restored
                ? 'restored'
                : 'active',
            source: 'google_play',
            planId: planId,
            renewalDate: DateTime.now().add(const Duration(days: 30)),
          );
          await _persistState();
          _pending[purchase.productID]?.complete(_state);
          _pending['__restore__']?.complete(_state);
        } else {
          final SubscriptionState failed = const SubscriptionState(
            isActive: false,
            status: 'verification_failed',
            source: 'google_play',
          );
          _pending[purchase.productID]?.complete(failed);
        }
        _pending.remove(purchase.productID);
        _pending.remove('__restore__');
        await _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        Logger.error('IAP purchase error', purchase.error);
        _pending[purchase.productID]
            ?.completeError(purchase.error ?? 'Purchase failed');
        _pending.remove(purchase.productID);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyWithServer(PurchaseDetails purchase) async {
    final String endpoint = Env.receiptVerifyEndpoint.trim();
    if (endpoint.isEmpty) {
      // No endpoint configured — trust Google Play result directly.
      Logger.warn('receiptVerifyEndpoint not set; skipping server verification.');
      return true;
    }

    try {
      final http.Response res = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'packageName': _kPackageName,
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
              'purchaseType': 'subscription',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        Logger.error('Receipt verify HTTP ${res.statusCode}');
        return false;
      }
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      return body['valid'] == true;
    } on Exception catch (e) {
      Logger.error('Receipt verification request failed', e);
      return false;
    }
  }

  Future<void> _loadPersistedState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final Map<String, dynamic> map =
          jsonDecode(raw) as Map<String, dynamic>;
      final DateTime? renewal = map['renewalDate'] != null
          ? DateTime.tryParse(map['renewalDate'] as String)
          : null;
      final bool isActive =
          map['isActive'] == true && (renewal == null || renewal.isAfter(DateTime.now()));
      _state = SubscriptionState(
        isActive: isActive,
        status: map['status'] as String? ?? 'locked',
        source: 'google_play',
        planId: map['planId'] as String?,
        renewalDate: renewal,
      );
    } on Exception catch (e) {
      Logger.error('Failed to load persisted subscription state', e);
    }
  }

  Future<void> _persistState() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        jsonEncode(<String, dynamic>{
          'isActive': _state.isActive,
          'status': _state.status,
          'planId': _state.planId,
          'renewalDate': _state.renewalDate?.toIso8601String(),
        }),
      );
    } on Exception catch (e) {
      Logger.error('Failed to persist subscription state', e);
    }
  }
}
