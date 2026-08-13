import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/monetization/data/models/models.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/analytics_events.dart';
import 'package:fantastic_guacamole/features/monetization/data/services/purchase_verification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

const String _pendingPurchaseJournalKey =
    'monetization_pending_purchase_journal_v1';
const Duration _purchaseResultTimeout = Duration(minutes: 2);
const Duration _restoreResultTimeout = Duration(seconds: 30);
const Duration _recoveryThrottle = Duration(seconds: 5);
const Duration _unlaunchedJournalRetention = Duration(hours: 1);
const Duration _orphanedJournalRetention = Duration(days: 7);

const Map<String, String> _knownPurchaseTypes = <String, String>{
  'chronospark_premium_monthly': 'subscription',
  'chronospark_premium_annual': 'subscription',
  'chronospark_lifetime': 'inapp',
  'chronospark_credits_100': 'inapp',
  'chronospark_credits_500': 'inapp',
  'chronospark_credits_1200': 'inapp',
  'chronospark_credits_3000': 'inapp',
};

const Set<String> _knownConsumableProductIds = <String>{
  'chronospark_credits_100',
  'chronospark_credits_500',
  'chronospark_credits_1200',
  'chronospark_credits_3000',
};

/// The exact platform operations used by pending-purchase recovery.
abstract interface class PurchaseRecoveryBillingGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds);
  Future<bool> buyNonConsumable(PurchaseParam param);
  Future<bool> buyConsumable(PurchaseParam param);
  Future<void> restorePurchases();
  Future<List<PurchaseDetails>?> recoverPendingPurchases();
  Future<void> finalizePurchase(
    PurchaseDetails purchase, {
    required bool isConsumable,
  });
}

/// Production adapter retaining the existing InAppPurchase behavior.
class InAppPurchaseRecoveryBillingGateway
    implements PurchaseRecoveryBillingGateway {
  InAppPurchaseRecoveryBillingGateway(this._iap);

  final InAppPurchase _iap;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) =>
      _iap.queryProductDetails(productIds);

  @override
  Future<bool> buyNonConsumable(PurchaseParam param) =>
      _iap.buyNonConsumable(purchaseParam: param);

  @override
  Future<bool> buyConsumable(PurchaseParam param) =>
      _iap.buyConsumable(purchaseParam: param, autoConsume: false);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  @override
  Future<List<PurchaseDetails>?> recoverPendingPurchases() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final InAppPurchaseAndroidPlatformAddition addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final QueryPurchaseDetailsResponse response = await addition
          .queryPastPurchases();
      return response.error == null ? response.pastPurchases : null;
    }
    await _iap.restorePurchases();
    return const <PurchaseDetails>[];
  }

  @override
  Future<void> finalizePurchase(
    PurchaseDetails purchase, {
    required bool isConsumable,
  }) async {
    if (isConsumable &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      final InAppPurchaseAndroidPlatformAddition addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final BillingResultWrapper result = await addition.consumePurchase(
        purchase,
      );
      if (result.responseCode != BillingResponse.ok) {
        throw StateError('Google Play did not consume the verified purchase.');
      }
    }
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}

class PurchaseResult {
  const PurchaseResult({
    required this.success,
    required this.productId,
    this.message,
    this.verifiedPlanId,
    this.creditsGranted,
    this.isPending = false,
  });

  final bool success;
  final String productId;
  final String? message;
  final String? verifiedPlanId;
  final int? creditsGranted;
  final bool isPending;
}

class PurchaseAuthContext {
  const PurchaseAuthContext({required this.userId, required this.accessToken});

  final String userId;
  final String accessToken;

  bool get isValid => userId.trim().isNotEmpty && accessToken.trim().isNotEmpty;
}

abstract class PurchaseRepository {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan);
  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack);
  Future<PurchaseResult> restorePurchases();
}

class GooglePlayPurchaseRepository implements PurchaseRepository {
  factory GooglePlayPurchaseRepository({
    InAppPurchase? iap,
    PurchaseRecoveryBillingGateway? billingGateway,
    required PurchaseVerifier verificationService,
    required SecureStore journalStore,
    required PurchaseAuthContext? Function() authContextLoader,
    Duration recoveryCooldown = _recoveryThrottle,
  }) {
    return GooglePlayPurchaseRepository._(
      billingGateway ??
          InAppPurchaseRecoveryBillingGateway(
            iap ?? (throw ArgumentError('iap is required without a gateway')),
          ),
      verificationService,
      journalStore,
      authContextLoader,
      recoveryCooldown,
    );
  }

  GooglePlayPurchaseRepository._(
    this._billing,
    this._verificationService,
    this._journalStore,
    this._authContextLoader,
    this._recoveryCooldown,
  ) {
    _initialization = _initialize();
    _purchaseSubscription = _billing.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: _onPurchaseStreamError,
    );
  }

  final PurchaseRecoveryBillingGateway _billing;
  final PurchaseVerifier _verificationService;
  final SecureStore _journalStore;
  final PurchaseAuthContext? Function() _authContextLoader;
  final Duration _recoveryCooldown;

  late final Future<void> _initialization;
  late final StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  final Map<String, _PendingPurchaseEntry> _journal =
      <String, _PendingPurchaseEntry>{};
  final Map<String, _PendingOperation> _operations =
      <String, _PendingOperation>{};
  final Set<String> _processingPurchaseKeys = <String>{};
  final StreamController<PurchaseResult> _verifiedPurchaseResults =
      StreamController<PurchaseResult>.broadcast();

  Future<void> _journalWriteTail = Future<void>.value();
  _RestoreOperation? _restoreOperation;
  DateTime? _lastRecoveryAt;
  bool _journalAvailable = false;
  bool _checkoutInProgress = false;
  bool _disposed = false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _billing.purchaseStream;

  Stream<PurchaseResult> get verifiedPurchaseResults =>
      _verifiedPurchaseResults.stream;

  @override
  Future<PurchaseResult> purchaseSubscription(SubscriptionPlan plan) async {
    final String purchaseType = _purchaseTypeForPlan(plan);
    AppAnalytics.track(MonetizationEvents.subscriptionPurchaseStarted);
    return _startPurchase(
      productId: plan.productId,
      purchaseType: purchaseType,
      isConsumable: false,
      launch: (PurchaseParam param) {
        return _billing.buyNonConsumable(param);
      },
    );
  }

  @override
  Future<PurchaseResult> purchaseCredits(AiCreditPackage pack) async {
    AppAnalytics.track(MonetizationEvents.creditPurchaseStarted);
    return _startPurchase(
      productId: pack.productId,
      purchaseType: 'inapp',
      isConsumable: true,
      launch: (PurchaseParam param) {
        return _billing.buyConsumable(param);
      },
    );
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    await _initialization;
    if (_disposed || !_journalAvailable) {
      return const PurchaseResult(
        success: false,
        productId: '__restore__',
        message: 'Secure purchase recovery is unavailable on this device.',
      );
    }
    final PurchaseAuthContext? auth = _validCurrentAuthContext();
    if (auth == null) {
      return const PurchaseResult(
        success: false,
        productId: '__restore__',
        message: 'Sign in before restoring purchases.',
      );
    }
    if (_restoreOperation != null) {
      return const PurchaseResult(
        success: false,
        productId: '__restore__',
        message: 'A restore is already in progress.',
        isPending: true,
      );
    }
    if (_checkoutInProgress) {
      return const PurchaseResult(
        success: false,
        productId: '__restore__',
        message: 'Wait for the current Google Play checkout to finish.',
        isPending: true,
      );
    }

    final Completer<PurchaseResult> completer = Completer<PurchaseResult>();
    final _RestoreOperation restore = _RestoreOperation(
      auth: auth,
      completer: completer,
    );
    _restoreOperation = restore;
    try {
      await _billing.restorePurchases();
      return await completer.future.timeout(
        _restoreResultTimeout,
        onTimeout: () => const PurchaseResult(
          success: false,
          productId: '__restore__',
          message: 'No restorable purchase was found.',
        ),
      );
    } on Object {
      return const PurchaseResult(
        success: false,
        productId: '__restore__',
        message: 'Google Play restore could not be completed.',
      );
    } finally {
      if (identical(_restoreOperation, restore)) {
        _restoreOperation = null;
      }
    }
  }

  Future<void> recoverPendingPurchases() async {
    await _initialization;
    if (_disposed || !_journalAvailable || _journal.isEmpty) {
      return;
    }
    final PurchaseAuthContext? auth = _validCurrentAuthContext();
    if (auth == null ||
        !_journal.values.any(
          (_PendingPurchaseEntry entry) => entry.userId == auth.userId,
        )) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? lastRecovery = _lastRecoveryAt;
    if (lastRecovery != null &&
        now.difference(lastRecovery) < _recoveryCooldown) {
      return;
    }
    _lastRecoveryAt = now;

    try {
      final List<PurchaseDetails>? purchases = await _billing
          .recoverPendingPurchases();
      if (purchases == null) {
        return;
      }
      _onPurchaseUpdates(purchases);
      await _reconcileJournalEntriesMissingFromStore(auth.userId, purchases);
    } on Object catch (error) {
      Logger.warn('Pending purchase recovery was unavailable: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _purchaseSubscription.cancel();
    const PurchaseResult disposedResult = PurchaseResult(
      success: false,
      productId: '__disposed__',
      message: 'Billing was closed before the purchase finished.',
      isPending: true,
    );
    for (final _PendingOperation operation in _operations.values) {
      if (!operation.completer.isCompleted) {
        operation.completer.complete(
          PurchaseResult(
            success: disposedResult.success,
            productId: operation.entry.productId,
            message: disposedResult.message,
            isPending: disposedResult.isPending,
          ),
        );
      }
    }
    _operations.clear();
    final _RestoreOperation? restore = _restoreOperation;
    if (restore != null && !restore.completer.isCompleted) {
      restore.completer.complete(disposedResult);
    }
    _restoreOperation = null;
    await _verifiedPurchaseResults.close();
  }

  Future<PurchaseResult> _startPurchase({
    required String productId,
    required String purchaseType,
    required bool isConsumable,
    required Future<bool> Function(PurchaseParam param) launch,
  }) async {
    await _initialization;
    if (_disposed || !_journalAvailable) {
      return PurchaseResult(
        success: false,
        productId: productId,
        message: 'Secure purchase recovery is unavailable on this device.',
      );
    }
    if (_checkoutInProgress) {
      return PurchaseResult(
        success: false,
        productId: productId,
        message: 'Another Google Play checkout is already in progress.',
        isPending: true,
      );
    }
    if (_journal.containsKey(productId)) {
      unawaited(recoverPendingPurchases());
      return PurchaseResult(
        success: false,
        productId: productId,
        message: 'A previous purchase is still awaiting confirmation.',
        isPending: true,
      );
    }

    PurchaseAuthContext? auth = _validCurrentAuthContext();
    if (auth == null) {
      return PurchaseResult(
        success: false,
        productId: productId,
        message: 'Sign in before starting a purchase.',
      );
    }

    _checkoutInProgress = true;
    try {
      final ProductDetailsResponse response = await _billing
          .queryProductDetails(<String>{productId});
      if (response.error != null) {
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'Google Play could not load this product.',
        );
      }
      final ProductDetails? product = _findProduct(
        response.productDetails,
        productId,
      );
      if (product == null) {
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'This Google Play product is not currently available.',
        );
      }

      final PurchaseAuthContext? currentAuth = _validCurrentAuthContext();
      if (currentAuth == null || currentAuth.userId != auth.userId) {
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'Your account changed before checkout could start.',
        );
      }
      auth = currentAuth;

      _PendingPurchaseEntry entry = _PendingPurchaseEntry(
        productId: productId,
        purchaseType: purchaseType,
        userId: auth.userId,
        isConsumable: isConsumable,
        createdAt: DateTime.now().toUtc(),
      );
      final Completer<PurchaseResult> completer = Completer<PurchaseResult>();
      final _PendingOperation operation = _PendingOperation(
        entry: entry,
        auth: auth,
        completer: completer,
      );

      _journal[productId] = entry;
      try {
        await _persistJournal();
      } on Object catch (error) {
        _journal.remove(productId);
        Logger.error('Pending purchase journal write failed', error);
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'Purchase recovery could not be secured on this device.',
        );
      }
      _operations[productId] = operation;

      final bool launched;
      try {
        launched = await launch(PurchaseParam(productDetails: product));
      } on Object {
        await _cancelPendingEntry(productId);
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'Google Play checkout could not be opened.',
        );
      }
      if (!launched) {
        await _cancelPendingEntry(productId);
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'Google Play checkout could not be opened.',
        );
      }

      entry = entry.copyWith(checkoutLaunched: true);
      _journal[productId] = entry;
      try {
        await _persistJournal();
      } on Object catch (error) {
        Logger.error('Launched purchase journal update failed', error);
      }

      try {
        return await completer.future.timeout(_purchaseResultTimeout);
      } on TimeoutException {
        if (identical(_operations[productId], operation)) {
          _operations.remove(productId);
        }
        return PurchaseResult(
          success: false,
          productId: productId,
          message: 'Google Play is still confirming this purchase.',
          isPending: true,
        );
      }
    } finally {
      _checkoutInProgress = false;
    }
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      final String processingKey = _processingKey(purchase);
      if (!_processingPurchaseKeys.add(processingKey)) {
        continue;
      }
      unawaited(
        _handlePurchase(
          purchase,
        ).whenComplete(() => _processingPurchaseKeys.remove(processingKey)),
      );
    }
  }

  void _onPurchaseStreamError(Object error, StackTrace stackTrace) {
    Logger.errorCategory(
      'billing',
      'Google Play purchase stream failed',
      error,
      stackTrace,
    );
    for (final _PendingOperation operation in _operations.values) {
      if (!operation.completer.isCompleted) {
        operation.completer.complete(
          PurchaseResult(
            success: false,
            productId: operation.entry.productId,
            message:
                'Google Play purchase updates are temporarily unavailable.',
            isPending: true,
          ),
        );
      }
    }
    _operations.clear();
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    await _initialization;
    if (_disposed) {
      return;
    }

    _PendingPurchaseEntry? entry = _journal[purchase.productID];
    final _RestoreOperation? restore = _restoreOperation;
    if (entry == null &&
        purchase.status == PurchaseStatus.restored &&
        restore != null) {
      final String? purchaseType = _knownPurchaseTypes[purchase.productID];
      if (purchaseType == null) {
        return;
      }
      entry = _PendingPurchaseEntry(
        productId: purchase.productID,
        purchaseType: purchaseType,
        userId: restore.auth.userId,
        isConsumable: _knownConsumableProductIds.contains(purchase.productID),
        createdAt: DateTime.now().toUtc(),
      );
      _journal[purchase.productID] = entry;
      try {
        await _persistJournal();
      } on Object catch (error) {
        _journal.remove(purchase.productID);
        Logger.error('Restored purchase journal write failed', error);
        return;
      }
    }
    if (entry == null) {
      return;
    }

    switch (purchase.status) {
      case PurchaseStatus.pending:
        return;
      case PurchaseStatus.error:
      case PurchaseStatus.canceled:
        _completeOperation(
          entry.productId,
          PurchaseResult(
            success: false,
            productId: entry.productId,
            message: purchase.status == PurchaseStatus.canceled
                ? 'The Google Play purchase was canceled.'
                : 'Google Play could not complete the purchase.',
          ),
        );
        await _removeJournalEntry(entry.productId);
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        break;
    }

    final String purchaseToken = purchase
        .verificationData
        .serverVerificationData
        .trim();
    if (purchaseToken.isEmpty) {
      _completeOperation(
        entry.productId,
        PurchaseResult(
          success: false,
          productId: entry.productId,
          message: 'Google Play did not provide a verifiable purchase token.',
          isPending: true,
        ),
      );
      return;
    }
    final String tokenHash = _hashPurchaseToken(purchaseToken);

    PurchaseVerificationResult? verification;
    if (!(entry.serverVerified && entry.purchaseTokenHash == tokenHash)) {
      final PurchaseAuthContext? auth = _verificationAuthFor(entry);
      if (auth == null) {
        return;
      }
      verification = await _verificationService.verifyPurchase(
        productId: entry.productId,
        purchaseToken: purchaseToken,
        purchaseType: entry.purchaseType,
        accessToken: auth.accessToken,
      );
      if (!verification.valid) {
        _trackPurchaseResult(entry, success: false);
        _completeOperation(
          entry.productId,
          PurchaseResult(
            success: false,
            productId: entry.productId,
            message: 'Purchase verification is still pending.',
            isPending: true,
          ),
        );
        return;
      }
      if (_disposed || !_isCurrentOwner(entry)) {
        return;
      }

      entry = entry.copyWith(
        serverVerified: true,
        purchaseTokenHash: tokenHash,
      );
      _journal[entry.productId] = entry;
      try {
        await _persistJournal();
      } on Object catch (error) {
        Logger.error('Verified purchase journal write failed', error);
        _completeOperation(
          entry.productId,
          PurchaseResult(
            success: false,
            productId: entry.productId,
            message: 'Verified purchase recovery could not be secured.',
            isPending: true,
          ),
        );
        return;
      }
    }

    if (_disposed || !_isCurrentOwner(entry)) {
      return;
    }

    try {
      await _billing.finalizePurchase(
        purchase,
        isConsumable: entry.isConsumable,
      );
    } on Object catch (error) {
      Logger.error('Verified Google Play purchase finalization failed', error);
      _completeOperation(
        entry.productId,
        PurchaseResult(
          success: false,
          productId: entry.productId,
          message:
              'The verified purchase is awaiting Google Play finalization.',
          isPending: true,
        ),
      );
      return;
    }

    await _removeJournalEntry(entry.productId);
    _trackPurchaseResult(entry, success: true);
    final PurchaseResult result = PurchaseResult(
      success: true,
      productId: entry.productId,
      message: 'Purchase verified.',
      verifiedPlanId: verification?.planId,
      creditsGranted: verification?.creditsGranted,
    );
    if (!_verifiedPurchaseResults.isClosed) {
      _verifiedPurchaseResults.add(result);
    }
    _completeOperation(entry.productId, result);
    final _RestoreOperation? activeRestore = _restoreOperation;
    if (activeRestore != null && !activeRestore.completer.isCompleted) {
      activeRestore.completer.complete(result);
    }
  }

  PurchaseAuthContext? _verificationAuthFor(_PendingPurchaseEntry entry) {
    final PurchaseAuthContext? current = _validCurrentAuthContext();
    if (current == null || current.userId != entry.userId) {
      return null;
    }
    final _PendingOperation? operation = _operations[entry.productId];
    if (operation != null && operation.auth.userId == entry.userId) {
      return operation.auth;
    }
    final _RestoreOperation? restore = _restoreOperation;
    if (restore != null && restore.auth.userId == entry.userId) {
      return restore.auth;
    }
    return current;
  }

  bool _isCurrentOwner(_PendingPurchaseEntry entry) {
    return _validCurrentAuthContext()?.userId == entry.userId;
  }

  PurchaseAuthContext? _validCurrentAuthContext() {
    final PurchaseAuthContext? auth = _authContextLoader();
    return auth != null && auth.isValid ? auth : null;
  }

  Future<void> _initialize() async {
    try {
      final String? raw = await _journalStore.readString(
        _pendingPurchaseJournalKey,
      );
      if (raw != null && raw.trim().isNotEmpty) {
        final Object? decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid purchase journal root.');
        }
        final Object? entries = decoded['entries'];
        if (entries is List) {
          for (final Object? value in entries) {
            final _PendingPurchaseEntry? entry = _PendingPurchaseEntry.tryParse(
              value,
            );
            if (entry != null) {
              _journal[entry.productId] = entry;
            }
          }
        }
      }
      _journalAvailable = true;
    } on Object catch (error) {
      _journalAvailable = false;
      Logger.error('Pending purchase journal could not be loaded', error);
      return;
    }
    if (_journal.isNotEmpty) {
      unawaited(recoverPendingPurchases());
    }
  }

  Future<void> _persistJournal() {
    final String payload = jsonEncode(<String, dynamic>{
      'version': 1,
      'entries': _journal.values
          .map((_PendingPurchaseEntry entry) => entry.toJson())
          .toList(growable: false),
    });
    final Future<void> write = _journalWriteTail.then(
      (_) => _journalStore.writeString(_pendingPurchaseJournalKey, payload),
    );
    _journalWriteTail = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return write;
  }

  Future<void> _cancelPendingEntry(String productId) async {
    _operations.remove(productId);
    await _removeJournalEntry(productId);
  }

  Future<void> _removeJournalEntry(String productId) async {
    final _PendingPurchaseEntry? removed = _journal.remove(productId);
    if (removed == null) {
      return;
    }
    try {
      await _persistJournal();
    } on Object catch (error) {
      _journal[productId] = removed;
      Logger.error('Pending purchase journal cleanup failed', error);
    }
  }

  Future<void> _reconcileJournalEntriesMissingFromStore(
    String userId,
    List<PurchaseDetails> purchases,
  ) async {
    final Set<String> storeTokenHashes = purchases
        .map(
          (PurchaseDetails purchase) => _hashPurchaseToken(
            purchase.verificationData.serverVerificationData,
          ),
        )
        .toSet();
    final Set<String> storeProductIds = purchases
        .map((PurchaseDetails purchase) => purchase.productID)
        .toSet();
    final DateTime now = DateTime.now().toUtc();
    final List<String> staleProductIds = _journal.values
        .where((_PendingPurchaseEntry entry) {
          if (entry.userId != userId) {
            return false;
          }
          if (entry.serverVerified &&
              entry.purchaseTokenHash != null &&
              !storeTokenHashes.contains(entry.purchaseTokenHash)) {
            return true;
          }
          if (storeProductIds.contains(entry.productId)) {
            return false;
          }
          final Duration age = now.difference(entry.createdAt);
          return (!entry.checkoutLaunched &&
                  age >= _unlaunchedJournalRetention) ||
              (!entry.serverVerified && age >= _orphanedJournalRetention);
        })
        .map((_PendingPurchaseEntry entry) => entry.productId)
        .toList(growable: false);
    for (final String productId in staleProductIds) {
      await _removeJournalEntry(productId);
    }
  }

  void _completeOperation(String productId, PurchaseResult result) {
    final _PendingOperation? operation = _operations.remove(productId);
    if (operation != null && !operation.completer.isCompleted) {
      operation.completer.complete(result);
    }
  }

  void _trackPurchaseResult(
    _PendingPurchaseEntry entry, {
    required bool success,
  }) {
    AppAnalytics.track(
      success
          ? (!entry.isConsumable
                ? MonetizationEvents.subscriptionPurchaseVerified
                : MonetizationEvents.creditPurchaseVerified)
          : (!entry.isConsumable
                ? MonetizationEvents.subscriptionPurchaseFailed
                : MonetizationEvents.creditPurchaseFailed),
    );
  }

  String _purchaseTypeForPlan(SubscriptionPlan plan) {
    final String? known = _knownPurchaseTypes[plan.productId];
    if (known != null) {
      return known;
    }
    final String normalizedType = plan.planType.trim().toLowerCase();
    if (normalizedType == 'inapp' ||
        normalizedType == 'lifetime' ||
        normalizedType == 'nonconsumable') {
      return 'inapp';
    }
    return 'subscription';
  }

  ProductDetails? _findProduct(
    List<ProductDetails> products,
    String productId,
  ) {
    for (final ProductDetails product in products) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  String _processingKey(PurchaseDetails purchase) {
    return '${purchase.productID}:${purchase.purchaseID ?? purchase.transactionDate ?? purchase.verificationData.serverVerificationData.hashCode}';
  }
}

class _PendingOperation {
  const _PendingOperation({
    required this.entry,
    required this.auth,
    required this.completer,
  });

  final _PendingPurchaseEntry entry;
  final PurchaseAuthContext auth;
  final Completer<PurchaseResult> completer;
}

class _RestoreOperation {
  const _RestoreOperation({required this.auth, required this.completer});

  final PurchaseAuthContext auth;
  final Completer<PurchaseResult> completer;
}

class _PendingPurchaseEntry {
  const _PendingPurchaseEntry({
    required this.productId,
    required this.purchaseType,
    required this.userId,
    required this.isConsumable,
    required this.createdAt,
    this.serverVerified = false,
    this.purchaseTokenHash,
    this.checkoutLaunched = false,
  });

  final String productId;
  final String purchaseType;
  final String userId;
  final bool isConsumable;
  final DateTime createdAt;
  final bool serverVerified;
  final String? purchaseTokenHash;
  final bool checkoutLaunched;

  _PendingPurchaseEntry copyWith({
    bool? serverVerified,
    String? purchaseTokenHash,
    bool? checkoutLaunched,
  }) {
    return _PendingPurchaseEntry(
      productId: productId,
      purchaseType: purchaseType,
      userId: userId,
      isConsumable: isConsumable,
      createdAt: createdAt,
      serverVerified: serverVerified ?? this.serverVerified,
      purchaseTokenHash: purchaseTokenHash ?? this.purchaseTokenHash,
      checkoutLaunched: checkoutLaunched ?? this.checkoutLaunched,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product_id': productId,
      'purchase_type': purchaseType,
      'user_id': userId,
      'is_consumable': isConsumable,
      'created_at': createdAt.toIso8601String(),
      'server_verified': serverVerified,
      'purchase_token_hash': purchaseTokenHash,
      'checkout_launched': checkoutLaunched,
    };
  }

  static _PendingPurchaseEntry? tryParse(Object? value) {
    if (value is! Map) {
      return null;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(value);
    final String productId = map['product_id']?.toString().trim() ?? '';
    final String purchaseType = map['purchase_type']?.toString() ?? '';
    final String userId = map['user_id']?.toString().trim() ?? '';
    final DateTime? createdAt = DateTime.tryParse(
      map['created_at']?.toString() ?? '',
    );
    if (productId.isEmpty ||
        userId.isEmpty ||
        createdAt == null ||
        (purchaseType != 'subscription' && purchaseType != 'inapp')) {
      return null;
    }
    final String? tokenHash = map['purchase_token_hash']?.toString();
    return _PendingPurchaseEntry(
      productId: productId,
      purchaseType: purchaseType,
      userId: userId,
      isConsumable: map['is_consumable'] == true,
      createdAt: createdAt,
      serverVerified: map['server_verified'] == true,
      purchaseTokenHash: tokenHash == null || tokenHash.isEmpty
          ? null
          : tokenHash,
      checkoutLaunched: map['checkout_launched'] == true,
    );
  }
}

String _hashPurchaseToken(String token) {
  return sha256.convert(utf8.encode(token)).toString();
}
