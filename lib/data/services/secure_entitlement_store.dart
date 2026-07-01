import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/system/subscription_model.dart';

abstract class EntitlementStore {
  Future<SubscriptionSnapshot?> readSubscription();
  Future<void> writeSubscription(SubscriptionSnapshot snapshot);
  Future<void> clearSubscription();
}

class SecureEntitlementStore implements EntitlementStore {
  SecureEntitlementStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _subscriptionKey = 'paywall_subscription_v1';
  static const String _legacyPremiumKey = 'paywall_premium_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<SubscriptionSnapshot?> readSubscription() async {
    final String? raw = await _storage.read(key: _subscriptionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final SubscriptionSnapshot snapshot =
          SubscriptionSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return snapshot.isValid ? snapshot : null;
    } catch (_) {
      await clearSubscription();
      return null;
    }
  }

  @override
  Future<void> writeSubscription(SubscriptionSnapshot snapshot) async {
    await _storage.write(key: _subscriptionKey, value: jsonEncode(snapshot.toJson()));
    await _storage.delete(key: _legacyPremiumKey);
  }

  @override
  Future<void> clearSubscription() async {
    await _storage.delete(key: _subscriptionKey);
    await _storage.delete(key: _legacyPremiumKey);
  }
}

class InMemoryEntitlementStore implements EntitlementStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<SubscriptionSnapshot?> readSubscription() async {
    final String? raw = _store[_subscriptionKey];
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final SubscriptionSnapshot snapshot =
        SubscriptionSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return snapshot.isValid ? snapshot : null;
  }

  @override
  Future<void> writeSubscription(SubscriptionSnapshot snapshot) async {
    _store[_subscriptionKey] = jsonEncode(snapshot.toJson());
  }

  @override
  Future<void> clearSubscription() async {
    _store.remove(_subscriptionKey);
  }

  static const String _subscriptionKey = 'paywall_subscription_v1';
}
