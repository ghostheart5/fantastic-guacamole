part of 'google_play_paywall_repository.dart';

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
  bool checkoutTimedOut = false;
}

class _PendingRestore {
  _PendingRestore({required this.userId}) {
    completer.future.ignore();
  }

  final String? userId;
  final Set<String> observedProductIds = <String>{};
  final Completer<SubscriptionState> completer = Completer<SubscriptionState>();
}

enum _PendingCreditRegistration {
  registered,
  canceled,
  completed,
  resolutionRequired,
  unverified,
}

extension _GooglePlayPaywallTransactionSupport on GooglePlayPaywallRepository {
  Future<SubscriptionState?> _retryPendingCreditRegistrationFromPlay(
    String productId,
    String? expectedUserId,
  ) async {
    final String? fingerprint = _billingAccountFingerprint(expectedUserId);
    if (!_creditAdmissionRequired ||
        !_hasReceiptVerification ||
        fingerprint == null ||
        !_isCurrentBillingAccount(expectedUserId)) {
      return null;
    }
    // Play's pending purchase inventory survives an app restart; no raw token
    // is written to local storage. A missing or failed inventory read leaves
    // the owner guard in place, so another checkout cannot be started. Bound
    // the read itself so a late result cannot clear a guard after timeout.
    final List<PurchaseDetails> purchases = await _billingClient
        .restorePurchases(applicationUserName: fingerprint)
        .timeout(_authorityRequestTimeout);
    if (!_isCurrentBillingAccount(expectedUserId)) return null;
    final String operationKey = _purchaseOperationKey(
      productId,
      expectedUserId,
    );
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.productID != productId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        final registration = await _registerPendingCreditTopupWithServer(
          purchase,
          expectedUserId: expectedUserId,
        );
        if (!_isCurrentBillingAccount(expectedUserId)) return null;
        if (registration == _PendingCreditRegistration.resolutionRequired) {
          final outcome = _transactionOutcomeState(
            status: 'customer_resolution_required',
            attemptedPlanId: _planIdForProduct(productId),
          );
          _completePendingPurchase(null, outcome);
          return outcome;
        }
        if (registration == _PendingCreditRegistration.canceled ||
            registration == _PendingCreditRegistration.completed) {
          await _clearPendingOwner(productId, expectedUserId);
          _approvalPending.remove(operationKey);
          final canceled = _transactionOutcomeState(
            status: registration == _PendingCreditRegistration.completed
                ? 'credits_added'
                : 'purchase_canceled',
            attemptedPlanId: _planIdForProduct(productId),
          );
          _completePendingPurchase(null, canceled);
          return canceled;
        }
        return _purchasePendingState(_planIdForProduct(productId));
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final String creditOutcome = await _verifiedCreditTopupFromServer(
          purchase,
          expectedUserId: expectedUserId,
        );
        if (!_isCurrentBillingAccount(expectedUserId)) return null;
        final SubscriptionState outcome = _transactionOutcomeState(
          status: creditOutcome,
          attemptedPlanId: null,
        );
        _completePendingPurchase(null, outcome);
        if (creditOutcome == 'credits_added' ||
            creditOutcome == 'purchase_canceled') {
          _approvalPending.remove(operationKey);
          await _clearPendingOwner(productId, expectedUserId);
        }
        return outcome;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        if (!_isCurrentBillingAccount(expectedUserId)) return null;
        await _clearPendingOwner(productId, expectedUserId);
        _approvalPending.remove(operationKey);
        final SubscriptionState canceled = _transactionOutcomeState(
          status: 'purchase_canceled',
          attemptedPlanId: _planIdForProduct(productId),
        );
        _completePendingPurchase(null, canceled);
        return canceled;
      }
      // A matching item in an unrecognized/error state is not evidence that
      // Play has removed the order. Keep the guard until a later read.
      return _purchasePendingState(_planIdForProduct(productId));
    }
    // Only a successful, account-bound inventory read with no matching
    // purchase can release a stale guard. A failed read never reaches here.
    if (_isCurrentBillingAccount(expectedUserId) &&
        !_purchaseStarts.containsKey(operationKey) &&
        !_pendingPurchases.containsKey(operationKey)) {
      await _clearPendingOwner(productId, expectedUserId);
      _approvalPending.remove(operationKey);
    }
    return null;
  }

  Future<String> _requirePublicCreditCheckoutAllowed(
    String? expectedUserId,
    String productId,
  ) async {
    final token = _supabaseClient?.auth.currentSession?.accessToken;
    if (expectedUserId == null ||
        token == null ||
        !_isCurrentBillingAccount(expectedUserId)) {
      throw StateError('Sign in before buying credits.');
    }
    try {
      final response = await _httpClient
          .post(
            parseSecureHttpsEndpoint(_receiptVerifyEndpoint)!,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'operation': 'credit_sale_eligibility',
              'productId': productId,
            }),
          )
          .timeout(_authorityRequestTimeout);
      final data = response.statusCode == 200
          ? jsonDecode(response.body)
          : null;
      if (data is Map &&
          data['valid'] == true &&
          data['checkoutAllowed'] == true &&
          data['admissionId'] is String &&
          (data['admissionId'] as String).isNotEmpty &&
          _isCurrentBillingAccount(expectedUserId)) {
        return data['admissionId'] as String;
      }
    } on Object {
      // A failed pre-check must never open Google Play checkout.
    }
    throw StateError('Credit packs are temporarily unavailable.');
  }

  Future<String> _verifiedCreditTopupFromServer(
    PurchaseDetails purchase, {
    required String? expectedUserId,
  }) async {
    if (!_hasReceiptVerification ||
        expectedUserId == null ||
        !_isCurrentBillingAccount(expectedUserId)) {
      return 'verification_failed';
    }
    final token = _supabaseClient?.auth.currentSession?.accessToken;
    if (token == null) {
      return 'verification_failed';
    }
    try {
      final response = await _httpClient
          .post(
            parseSecureHttpsEndpoint(_receiptVerifyEndpoint)!,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
              'purchaseType': 'inapp',
              if (_requireTestPurchase) 'requireTestPurchase': true,
            }),
          )
          .timeout(_authorityRequestTimeout);
      if (response.statusCode != 200 ||
          !_isCurrentBillingAccount(expectedUserId)) {
        return 'verification_failed';
      }
      final data = jsonDecode(response.body);
      if (_creditAdmissionRequired &&
          data is Map &&
          data['valid'] == false &&
          data['error'] == 'purchase_not_completed') {
        // Play can retain PURCHASED inventory after a refund. Read the
        // existing cancellation authority and require its exact token proof;
        // the generic verification error alone cannot release ownership.
        final registration = await _registerPendingCreditTopupWithServer(
          purchase,
          expectedUserId: expectedUserId,
          recoverCompletedPurchase: false,
        );
        if (registration == _PendingCreditRegistration.canceled &&
            _isCurrentBillingAccount(expectedUserId)) {
          return 'purchase_canceled';
        }
        return 'verification_failed';
      }
      final expectedCredits = purchase.productID == 'chronospark_credits_100'
          ? 100
          : 300;
      if (data is Map &&
          data['error'] == 'customer_resolution_required' &&
          data['resolutionQueued'] == true) {
        return 'customer_resolution_required';
      }
      final bool verified =
          data is Map &&
          data['valid'] == true &&
          data['consumed'] == true &&
          data['productId'] == purchase.productID &&
          data['creditsGranted'] == expectedCredits &&
          (!_requireTestPurchase || data['testPurchase'] == true);
      return verified ? 'credits_added' : 'verification_failed';
    } on Object {
      return 'verification_failed';
    }
  }

  Future<_PendingCreditRegistration> _registerPendingCreditTopupWithServer(
    PurchaseDetails purchase, {
    required String? expectedUserId,
    bool recoverCompletedPurchase = true,
  }) async {
    if (!_hasReceiptVerification ||
        expectedUserId == null ||
        !_isCurrentBillingAccount(expectedUserId)) {
      return _PendingCreditRegistration.unverified;
    }
    final token = _supabaseClient?.auth.currentSession?.accessToken;
    if (token == null) {
      return _PendingCreditRegistration.unverified;
    }
    try {
      final response = await _httpClient
          .post(
            parseSecureHttpsEndpoint(_receiptVerifyEndpoint)!,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'operation': 'credit_register_pending',
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
              'purchaseType': 'inapp',
              if (_requireTestPurchase) 'requireTestPurchase': true,
            }),
          )
          .timeout(_authorityRequestTimeout);
      if (response.statusCode != 200 ||
          !_isCurrentBillingAccount(expectedUserId)) {
        return _PendingCreditRegistration.unverified;
      }
      final data = jsonDecode(response.body);
      if (data is Map && data['error'] == 'purchase_not_pending') {
        if (!recoverCompletedPurchase) {
          return _PendingCreditRegistration.unverified;
        }
        // A device inventory can lag a completed payment as well as a
        // cancellation. Only the normal server fulfillment proof can release
        // this guard; never infer delivery from the registration error alone.
        final outcome = await _verifiedCreditTopupFromServer(
          purchase,
          expectedUserId: expectedUserId,
        );
        return switch (outcome) {
          'credits_added' => _PendingCreditRegistration.completed,
          'purchase_canceled' => _PendingCreditRegistration.canceled,
          'customer_resolution_required' =>
            _PendingCreditRegistration.resolutionRequired,
          _ => _PendingCreditRegistration.unverified,
        };
      }
      if (data is Map &&
          data['valid'] == true &&
          data['purchaseCanceled'] == true &&
          data['productId'] == purchase.productID &&
          data['tokenHash'] ==
              sha256
                  .convert(
                    utf8.encode(
                      purchase.verificationData.serverVerificationData,
                    ),
                  )
                  .toString()) {
        return _PendingCreditRegistration.canceled;
      }
      return data is Map &&
              data['valid'] == true &&
              data['pendingRegistered'] == true
          ? _PendingCreditRegistration.registered
          : _PendingCreditRegistration.unverified;
    } on Object {
      return _PendingCreditRegistration.unverified;
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
        state.status == 'customer_resolution_required' ||
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
    final userId = pending?.userId ?? _supabaseClient?.auth.currentUser?.id;
    if (!_disposed && _isCurrentBillingAccount(userId)) {
      _purchaseOutcomes.add(PurchaseOutcome(userId, state));
    }
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
            body: jsonEncode(<String, Object>{
              'productId': purchase.productID,
              'purchaseToken': purchase.verificationData.serverVerificationData,
              'purchaseType': 'subscription',
              if (_requireTestPurchase) 'requireTestPurchase': true,
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
      if (_requireTestPurchase && body['testPurchase'] != true) {
        Logger.error(
          'This build requires a verified Google Play test purchase.',
        );
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
}
