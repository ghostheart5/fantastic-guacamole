part of 'google_play_paywall_repository.dart';

extension _GooglePlayPaywallTransactionSupport on GooglePlayPaywallRepository {
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
}
