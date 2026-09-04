part of 'google_play_paywall_repository.dart';

extension _GooglePlayPaywallPersistenceSupport on GooglePlayPaywallRepository {
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
    final int revision =
        (GooglePlayPaywallRepository._persistenceRevisions[storageKey] ?? 0) +
        1;
    GooglePlayPaywallRepository._persistenceRevisions[storageKey] = revision;
    final Future<void> previous =
        GooglePlayPaywallRepository._persistenceQueues[storageKey] ??
        Future<void>.value();
    late final Future<void> queued;
    queued = previous.catchError((Object _) {}).then((_) async {
      if (GooglePlayPaywallRepository._persistenceRevisions[storageKey] !=
          revision) {
        return;
      }
      await _writePersistedState(storageKey, encoded);
    });
    GooglePlayPaywallRepository._persistenceQueues[storageKey] = queued;
    try {
      await queued;
    } on Exception catch (error) {
      Logger.error('Failed to persist subscription state', error);
    } finally {
      if (identical(
        GooglePlayPaywallRepository._persistenceQueues[storageKey],
        queued,
      )) {
        GooglePlayPaywallRepository._persistenceQueues
            .remove(storageKey)
            ?.ignore();
        GooglePlayPaywallRepository._persistenceRevisions.remove(storageKey);
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
