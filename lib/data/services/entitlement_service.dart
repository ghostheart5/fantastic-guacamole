import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/system/subscription_model.dart';

/// A server-issued record confirming a user's current entitlement.
///
/// The server generates and signs this record after independently validating
/// a purchase receipt. The client never constructs this itself — receiving it
/// proves the server has authorised access.
class EntitlementRecord {
  const EntitlementRecord({
    required this.entitlementId,
    required this.userId,
    required this.plan,
    required this.billingCycle,
    required this.status,
    required this.grantedAt,
    required this.expiresAt,
  });

  /// Server-generated opaque ID. Its presence proves the server issued the grant.
  final String entitlementId;
  final String userId;
  final SubscriptionPlan plan;
  final BillingCycle billingCycle;
  final SubscriptionStatus status;
  final DateTime grantedAt;
  final DateTime expiresAt;

  bool get isActive => status == SubscriptionStatus.active;

  /// Convert to the local snapshot shape used by the rest of the app.
  SubscriptionSnapshot toSnapshot() {
    return SubscriptionSnapshot(
      plan: plan,
      billingCycle: billingCycle,
      status: status,
      subscriptionStartDate: grantedAt,
      mockNextBillingDate: expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'entitlementId': entitlementId,
      'userId': userId,
      'plan': plan.name,
      'billingCycle': billingCycle.name,
      'status': status.name,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory EntitlementRecord.fromJson(Map<String, dynamic> json) {
    return EntitlementRecord(
      entitlementId: json['entitlementId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (SubscriptionPlan e) => e.name == (json['plan'] as String? ?? ''),
        orElse: () => SubscriptionPlan.base,
      ),
      billingCycle: BillingCycle.values.firstWhere(
        (BillingCycle e) => e.name == (json['billingCycle'] as String? ?? ''),
        orElse: () => BillingCycle.monthly,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (SubscriptionStatus e) => e.name == (json['status'] as String? ?? ''),
        orElse: () => SubscriptionStatus.active,
      ),
      grantedAt: DateTime.tryParse(json['grantedAt'] as String? ?? '') ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
    );
  }
}

class EntitlementException implements Exception {
  EntitlementException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Server-authoritative entitlement service.
///
/// This is the single source of truth for subscription status. The app always
/// *requests* entitlement from the server rather than constructing or trusting
/// locally stored access flags.
///
/// ## Pattern overview
///
/// 1. **On startup**: call [fetchEntitlement] to learn what the server says
///    the user has access to. This replaces reading a cached `isPremium` bool
///    from SharedPreferences — local values could be stale or tampered with.
///
/// 2. **After purchase**: call [activateEntitlement] with the receipt the
///    billing processor returned. The server validates the receipt independently
///    (with Apple/Google/Stripe) and then issues its own [EntitlementRecord].
///    The client uses that record, not the billing processor's output, to
///    decide what features are unlocked.
///
/// 3. **Downgrade / cancel**: call [revokeEntitlement]. The server revokes
///    the grant and returns a Base-tier record. The client applies that.
///
/// ## Mock mode vs HTTP mode
///
/// - **Mock mode** (default, no env var set): an in-memory map simulates the
///   server. Entitlements are granted instantly and survive only for the
///   current app session — perfect for development and CI.
///
/// - **HTTP mode**: set `CHRONOSPARK_ENTITLEMENT_ENDPOINT` at build time to
///   point at a real backend. The service makes POST/GET requests and parses
///   the JSON response.
///
/// Either way the client-side call sites are identical, making it easy to
/// swap the mock for a real server.
class EntitlementService {
  EntitlementService({http.Client? client, String? endpoint, String? apiKey})
    : _client = client ?? http.Client(),
      _endpoint =
          endpoint ??
          const String.fromEnvironment(
            'CHRONOSPARK_ENTITLEMENT_ENDPOINT',
            defaultValue: '',
          ),
      _apiKey =
          apiKey ??
          const String.fromEnvironment('CHRONOSPARK_ENTITLEMENT_KEY', defaultValue: '');

  static const String _deviceIdKey = 'chronospark_device_id';
  static const Duration _cacheTtl = Duration(hours: 1);

  final http.Client _client;
  final String _endpoint;
  final String _apiKey;

  // Simulates what a real server would persist in a database.
  // Keyed by userId. Populated only during the current app session.
  final Map<String, EntitlementRecord> _mockServerStore = <String, EntitlementRecord>{};

  // Short-lived cache so repeated access-checks don't hit the server every time.
  EntitlementRecord? _cachedRecord;
  DateTime? _cacheExpiry;

  bool get isConfigured => _endpoint.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Device identity
  // ---------------------------------------------------------------------------

  /// Returns a stable device-level ID, creating and persisting one on first run.
  ///
  /// In a production app with user authentication this would be the signed-in
  /// user's UID (e.g. Firebase Auth UID). Using a device ID here keeps the
  /// example self-contained.
  Future<String> getOrCreateDeviceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String generated = _generateId();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  // ---------------------------------------------------------------------------
  // Server requests
  // ---------------------------------------------------------------------------

  /// Ask the server what this user is currently entitled to.
  ///
  /// Always call this on app startup rather than reading a locally stored plan.
  /// Local values can be stale, modified, or simply wrong after the billing
  /// provider changes the subscription state (e.g. renewal failure, refund).
  Future<EntitlementRecord?> fetchEntitlement(String userId) async {
    // Serve from cache while still fresh.
    if (_cachedRecord != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      return _cachedRecord;
    }

    if (isConfigured) {
      return _httpFetchEntitlement(userId);
    }

    // Mock server path: simulate a GET /entitlements/{userId} round-trip.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final EntitlementRecord? record = _mockServerStore[userId];
    _updateCache(record);
    return record;
  }

  /// Tell the server that the billing processor completed a purchase and send
  /// it the receipt so it can validate the transaction independently.
  ///
  /// The server validates the receipt with Apple / Google / Stripe, then
  /// creates its own entitlement record and returns it. The client uses the
  /// server-issued record — not the billing processor's output — to unlock
  /// features. This prevents the client from self-granting access.
  Future<EntitlementRecord> activateEntitlement({
    required String userId,
    required SubscriptionPlan plan,
    required BillingCycle billingCycle,
    required String purchaseReceipt,
  }) async {
    if (purchaseReceipt.isEmpty) {
      throw EntitlementException(
        'Cannot activate entitlement: purchase receipt is missing.',
      );
    }

    if (isConfigured) {
      return _httpActivateEntitlement(userId, plan, billingCycle, purchaseReceipt);
    }

    // Mock server path: simulate server-side receipt validation then grant.
    // Production servers would call Apple/Google APIs here before responding.
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final DateTime now = DateTime.now();
    final EntitlementRecord record = EntitlementRecord(
      entitlementId: 'ent_${_generateId()}',
      userId: userId,
      plan: plan,
      billingCycle: billingCycle,
      status: SubscriptionStatus.active,
      grantedAt: now,
      expiresAt: now.add(Duration(days: billingCycle.billingIntervalDays)),
    );
    _mockServerStore[userId] = record;
    _updateCache(record);
    return record;
  }

  /// Ask the server to revoke premium access (downgrade to Base or cancel).
  ///
  /// The server records the change and returns an updated [EntitlementRecord]
  /// reflecting the new state. The client applies that record — it does not
  /// determine the new plan locally.
  Future<EntitlementRecord> revokeEntitlement(String userId) async {
    if (isConfigured) {
      return _httpRevokeEntitlement(userId);
    }

    // Mock server path: simulate a DELETE /entitlements/{userId} round-trip.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final DateTime now = DateTime.now();
    // Base plan is treated as perpetually active — no billing expiry applies.
    final EntitlementRecord record = EntitlementRecord(
      entitlementId: 'ent_${_generateId()}',
      userId: userId,
      plan: SubscriptionPlan.base,
      billingCycle: BillingCycle.monthly,
      status: SubscriptionStatus.active,
      grantedAt: now,
      expiresAt: now.add(const Duration(days: 36500)),
    );
    _mockServerStore[userId] = record;
    _updateCache(record);
    return record;
  }

  /// Apply a promo code server-side and return the updated entitlement.
  ///
  /// The server validates the code and extends the billing period; the client
  /// accepts whatever the server returns.
  Future<EntitlementRecord> applyPromoCode(String userId, String code) async {
    if (code.trim().length < 3) {
      throw EntitlementException('Invalid promo code.');
    }

    if (isConfigured) {
      return _httpApplyPromo(userId, code);
    }

    // Mock server path: extend expiry by 30 days as a promo reward.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final EntitlementRecord? current = _mockServerStore[userId];
    if (current == null || !current.plan.isPremium) {
      throw EntitlementException('Promo codes only apply to active premium subscriptions.');
    }

    final EntitlementRecord updated = EntitlementRecord(
      entitlementId: 'ent_${_generateId()}',
      userId: current.userId,
      plan: current.plan,
      billingCycle: current.billingCycle,
      status: current.status,
      grantedAt: current.grantedAt,
      expiresAt: current.expiresAt.add(const Duration(days: 30)),
    );
    _mockServerStore[userId] = updated;
    _updateCache(updated);
    return updated;
  }

  /// Force the next [fetchEntitlement] call to go to the server, bypassing
  /// the local cache. Call this after known subscription changes.
  void invalidateCache() {
    _cachedRecord = null;
    _cacheExpiry = null;
  }

  // ---------------------------------------------------------------------------
  // HTTP paths (production)
  // ---------------------------------------------------------------------------

  Future<EntitlementRecord?> _httpFetchEntitlement(String userId) async {
    final Map<String, String> headers = _buildHeaders();
    final http.Response response = await _client.get(
      Uri.parse('$_endpoint/$userId'),
      headers: headers,
    );
    if (response.statusCode == 404) {
      _updateCache(null);
      return null;
    }
    _assertSuccess(response);
    final EntitlementRecord record =
        EntitlementRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _updateCache(record);
    return record;
  }

  Future<EntitlementRecord> _httpActivateEntitlement(
    String userId,
    SubscriptionPlan plan,
    BillingCycle billingCycle,
    String purchaseReceipt,
  ) async {
    final http.Response response = await _client.post(
      Uri.parse(_endpoint),
      headers: _buildHeaders(),
      body: jsonEncode(<String, dynamic>{
        'userId': userId,
        'plan': plan.name,
        'billingCycle': billingCycle.name,
        'purchaseReceipt': purchaseReceipt,
      }),
    );
    _assertSuccess(response);
    final EntitlementRecord record =
        EntitlementRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _updateCache(record);
    return record;
  }

  Future<EntitlementRecord> _httpRevokeEntitlement(String userId) async {
    final http.Response response = await _client.delete(
      Uri.parse('$_endpoint/$userId'),
      headers: _buildHeaders(),
    );
    _assertSuccess(response);
    final EntitlementRecord record =
        EntitlementRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _updateCache(record);
    return record;
  }

  Future<EntitlementRecord> _httpApplyPromo(String userId, String code) async {
    final http.Response response = await _client.post(
      Uri.parse('$_endpoint/$userId/promo'),
      headers: _buildHeaders(),
      body: jsonEncode(<String, dynamic>{'code': code}),
    );
    _assertSuccess(response);
    final EntitlementRecord record =
        EntitlementRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _updateCache(record);
    return record;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, String> _buildHeaders() {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  void _assertSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EntitlementException(
        'Entitlement server returned ${response.statusCode}: ${response.body}',
      );
    }
  }

  void _updateCache(EntitlementRecord? record) {
    _cachedRecord = record;
    _cacheExpiry = DateTime.now().add(_cacheTtl);
  }

  static final Random _random = Random.secure();

  static String _generateId() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      16,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
