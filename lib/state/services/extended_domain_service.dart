import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExtendedDomainService implements IExtendedDomainRepository {
  ExtendedDomainService({required AccountStorageScope storageScope})
    : _namespace = storageScope.isAuthenticated
          ? storageScope.v2Namespace
          : null;

  static const String _keyCoachMessages = 'extended_domain.coach_messages';
  static const String _keySiQueries = 'extended_domain.si_queries';
  static const String _keyUserIntents = 'extended_domain.user_intents';
  static const String _keyJournalEntries = 'extended_domain.journal_entries';
  static const String _keyAnalyticsMetrics =
      'extended_domain.analytics_metrics';
  static const String _keyAppNotifications =
      'extended_domain.app_notifications';
  static const String _keyRewards = 'extended_domain.rewards';
  static const String _keyThemes = 'extended_domain.themes';
  static const String _keySettings = 'extended_domain.settings';
  static const String _keySyncStates = 'extended_domain.sync_states';
  static const String _keyOfflineStates = 'extended_domain.offline_states';
  static const String _keyAppErrors = 'extended_domain.app_errors';
  static const String _keyRecoveryStates = 'extended_domain.recovery_states';
  static const String _keySubscriptionPlans =
      'extended_domain.subscription_plans';
  static const String _keyPrivacyPolicies = 'extended_domain.privacy_policies';
  static const String _keyHealthChecks = 'extended_domain.health_checks';

  static const List<String> legacyStorageKeys = <String>[
    _keyCoachMessages,
    _keySiQueries,
    _keyUserIntents,
    _keyJournalEntries,
    _keyAnalyticsMetrics,
    _keyAppNotifications,
    _keyRewards,
    _keyThemes,
    _keySettings,
    _keySyncStates,
    _keyOfflineStates,
    _keyAppErrors,
    _keyRecoveryStates,
    _keySubscriptionPlans,
    _keyPrivacyPolicies,
    _keyHealthChecks,
  ];

  static String scopedStorageKey(String baseKey, String storageScope) {
    return '$baseKey.${_safeStorageScope(storageScope)}';
  }

  /// The only active authenticated storage location for this family.
  static String canonicalStorageKeyForScope(
    String baseKey,
    AccountStorageScope storageScope,
  ) {
    final String? namespace = storageScope.v2Namespace;
    if (!storageScope.isAuthenticated || namespace == null) {
      throw StateError(
        'ExtendedDomain requires an authenticated storage scope',
      );
    }
    return '$baseKey.$namespace';
  }

  static Future<void> migrateLegacyStorage({
    required SharedPreferences prefs,
    required String storageScope,
  }) async {}

  static String _safeStorageScope(String value) {
    final String normalized = value.trim().replaceAll(
      RegExp('[^a-zA-Z0-9._-]'),
      '_',
    );
    return normalized.isEmpty ? 'signed_out' : normalized;
  }

  SharedPreferences? _prefs;
  final String? _namespace;
  bool _initialized = false;
  bool _disposed = false;
  int _lifecycleGeneration = 0;
  Future<void> _writeTail = Future<void>.value();

  final List<CoachMessage> _coachMessages = [];
  final List<SiQuery> _siQueries = [];
  final List<UserIntent> _userIntents = [];
  final List<JournalEntry> _journalEntries = [];
  final List<AnalyticsMetric> _analyticsMetrics = [];
  final List<AppNotification> _appNotifications = [];
  final List<Reward> _rewards = [];
  final List<AppTheme> _themes = [];
  final List<AppSetting> _settings = [];
  final List<SyncState> _syncStates = [];
  final List<OfflineState> _offlineStates = [];
  final List<AppError> _appErrors = [];
  final List<RecoveryState> _recoveryStates = [];
  final List<SubscriptionPlanEntity> _subscriptionPlans = [];
  final List<PrivacyPolicy> _privacyPolicies = [];
  final List<HealthCheckResult> _healthChecks = [];

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    if (_namespace == null) return;
    final int generation = _lifecycleGeneration;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (generation != _lifecycleGeneration) return;
    _prefs = prefs;
    _hydrateState();
    _initialized = true;
  }

  Future<void> cancelAndDrain() async {
    _markDisposed();
    await _writeTail.catchError((Object _) {});
  }

  void dispose() => _markDisposed();

  void _markDisposed() {
    if (_disposed) return;
    _disposed = true;
    _lifecycleGeneration++;
    _initialized = false;
    _prefs = null;
    _coachMessages.clear();
    _siQueries.clear();
    _userIntents.clear();
    _journalEntries.clear();
    _analyticsMetrics.clear();
    _appNotifications.clear();
    _rewards.clear();
    _themes.clear();
    _settings.clear();
    _syncStates.clear();
    _offlineStates.clear();
    _appErrors.clear();
    _recoveryStates.clear();
    _subscriptionPlans.clear();
    _privacyPolicies.clear();
    _healthChecks.clear();
  }

  void _hydrateState() {
    final SharedPreferences prefs = _prefs!;

    _coachMessages
      ..clear()
      ..addAll(
        _decodeEntities<CoachMessage>(
          prefs.getString(_activeKey(_keyCoachMessages)),
          (Map<String, dynamic> json) => CoachMessage(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _siQueries
      ..clear()
      ..addAll(
        _decodeEntities<SiQuery>(
          prefs.getString(_activeKey(_keySiQueries)),
          (Map<String, dynamic> json) => SiQuery(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _userIntents
      ..clear()
      ..addAll(
        _decodeEntities<UserIntent>(
          prefs.getString(_activeKey(_keyUserIntents)),
          (Map<String, dynamic> json) => UserIntent(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _journalEntries
      ..clear()
      ..addAll(
        _decodeEntities<JournalEntry>(
          prefs.getString(_activeKey(_keyJournalEntries)),
          (Map<String, dynamic> json) => JournalEntry(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _analyticsMetrics
      ..clear()
      ..addAll(
        _decodeEntities<AnalyticsMetric>(
          prefs.getString(_activeKey(_keyAnalyticsMetrics)),
          (Map<String, dynamic> json) => AnalyticsMetric(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _appNotifications
      ..clear()
      ..addAll(
        _decodeEntities<AppNotification>(
          prefs.getString(_activeKey(_keyAppNotifications)),
          (Map<String, dynamic> json) => AppNotification(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _rewards
      ..clear()
      ..addAll(
        _decodeEntities<Reward>(
          prefs.getString(_activeKey(_keyRewards)),
          (Map<String, dynamic> json) =>
              Reward(id: json['id'] as String, label: json['label'] as String?),
        ),
      );
    _themes
      ..clear()
      ..addAll(
        _decodeEntities<AppTheme>(
          prefs.getString(_activeKey(_keyThemes)),
          (Map<String, dynamic> json) => AppTheme(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _settings
      ..clear()
      ..addAll(
        _decodeEntities<AppSetting>(
          prefs.getString(_activeKey(_keySettings)),
          (Map<String, dynamic> json) => AppSetting(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _syncStates
      ..clear()
      ..addAll(
        _decodeEntities<SyncState>(
          prefs.getString(_activeKey(_keySyncStates)),
          (Map<String, dynamic> json) => SyncState(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _offlineStates
      ..clear()
      ..addAll(
        _decodeEntities<OfflineState>(
          prefs.getString(_activeKey(_keyOfflineStates)),
          (Map<String, dynamic> json) => OfflineState(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _appErrors
      ..clear()
      ..addAll(
        _decodeEntities<AppError>(
          prefs.getString(_activeKey(_keyAppErrors)),
          (Map<String, dynamic> json) => AppError(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _recoveryStates
      ..clear()
      ..addAll(
        _decodeEntities<RecoveryState>(
          prefs.getString(_activeKey(_keyRecoveryStates)),
          (Map<String, dynamic> json) => RecoveryState(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _subscriptionPlans
      ..clear()
      ..addAll(
        _decodeEntities<SubscriptionPlanEntity>(
          prefs.getString(_activeKey(_keySubscriptionPlans)),
          (Map<String, dynamic> json) => SubscriptionPlanEntity(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _privacyPolicies
      ..clear()
      ..addAll(
        _decodeEntities<PrivacyPolicy>(
          prefs.getString(_activeKey(_keyPrivacyPolicies)),
          (Map<String, dynamic> json) => PrivacyPolicy(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
    _healthChecks
      ..clear()
      ..addAll(
        _decodeEntities<HealthCheckResult>(
          prefs.getString(_activeKey(_keyHealthChecks)),
          (Map<String, dynamic> json) => HealthCheckResult(
            id: json['id'] as String,
            label: json['label'] as String?,
          ),
        ),
      );
  }

  List<T> _decodeEntities<T>(
    String? encoded,
    T Function(Map<String, dynamic> json) parser,
  ) {
    if (encoded == null || encoded.isEmpty) {
      return <T>[];
    }
    try {
      final dynamic decodedAny = jsonDecode(encoded);
      if (decodedAny is! List) {
        return <T>[];
      }
      return decodedAny
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => parser(
              item.map<String, dynamic>(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList(growable: false);
    } on Object {
      return <T>[];
    }
  }

  Future<void> _persistList(String key, Iterable<LightweightEntity> entities) {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null || _disposed || _namespace == null) {
      return Future<void>.value();
    }
    final String encoded = jsonEncode(
      entities
          .map(
            (LightweightEntity entity) => <String, dynamic>{
              'id': entity.id,
              'label': entity.label,
            },
          )
          .toList(growable: false),
    );
    final int generation = _lifecycleGeneration;
    final Future<void> previous = _writeTail.catchError((Object _) {});
    final Future<void> write = previous.then((_) async {
      if (_disposed || generation != _lifecycleGeneration) return;
      await prefs.setString(_activeKey(key), encoded);
    });
    _writeTail = write;
    return write;
  }

  String _activeKey(String baseKey) => '$baseKey.$_namespace';

  bool get _canUseStorage => _namespace != null && !_disposed;

  @override
  List<CoachMessage> getCoachMessages() => List.unmodifiable(_coachMessages);

  @override
  List<SiQuery> getSiQueries() => List.unmodifiable(_siQueries);

  @override
  List<UserIntent> getUserIntents() => List.unmodifiable(_userIntents);

  @override
  List<JournalEntry> getJournalEntries() => List.unmodifiable(_journalEntries);

  @override
  List<AnalyticsMetric> getAnalyticsMetrics() =>
      List.unmodifiable(_analyticsMetrics);

  @override
  List<AppNotification> getAppNotifications() =>
      List.unmodifiable(_appNotifications);

  @override
  List<Reward> getRewards() => List.unmodifiable(_rewards);

  @override
  List<AppTheme> getThemes() => List.unmodifiable(_themes);

  @override
  List<AppSetting> getSettings() => List.unmodifiable(_settings);

  @override
  List<SyncState> getSyncStates() => List.unmodifiable(_syncStates);

  @override
  List<OfflineState> getOfflineStates() => List.unmodifiable(_offlineStates);

  @override
  List<AppError> getAppErrors() => List.unmodifiable(_appErrors);

  @override
  List<RecoveryState> getRecoveryStates() => List.unmodifiable(_recoveryStates);

  @override
  List<SubscriptionPlanEntity> getSubscriptionPlans() =>
      List.unmodifiable(_subscriptionPlans);

  @override
  List<PrivacyPolicy> getPrivacyPolicies() =>
      List.unmodifiable(_privacyPolicies);

  @override
  List<HealthCheckResult> getHealthChecks() => List.unmodifiable(_healthChecks);

  @override
  Future<void> saveCoachMessage(CoachMessage entity) async {
    if (!_canUseStorage) return;
    _coachMessages.add(entity);
    await _persistList(_keyCoachMessages, _coachMessages);
  }

  @override
  Future<void> saveSiQuery(SiQuery entity) async {
    if (!_canUseStorage) return;
    _siQueries.add(entity);
    await _persistList(_keySiQueries, _siQueries);
  }

  @override
  Future<void> saveUserIntent(UserIntent entity) async {
    if (!_canUseStorage) return;
    _userIntents.add(entity);
    await _persistList(_keyUserIntents, _userIntents);
  }

  @override
  Future<void> saveJournalEntry(JournalEntry entity) async {
    if (!_canUseStorage) return;
    _journalEntries.add(entity);
    await _persistList(_keyJournalEntries, _journalEntries);
  }

  @override
  Future<void> saveAnalyticsMetric(AnalyticsMetric entity) async {
    if (!_canUseStorage) return;
    _analyticsMetrics.add(entity);
    await _persistList(_keyAnalyticsMetrics, _analyticsMetrics);
  }

  @override
  Future<void> saveAppNotification(AppNotification entity) async {
    if (!_canUseStorage) return;
    _appNotifications.add(entity);
    await _persistList(_keyAppNotifications, _appNotifications);
  }

  @override
  Future<void> saveReward(Reward entity) async {
    if (!_canUseStorage) return;
    _rewards.add(entity);
    await _persistList(_keyRewards, _rewards);
  }

  @override
  Future<void> saveAppTheme(AppTheme entity) async {
    if (!_canUseStorage) return;
    _themes.add(entity);
    await _persistList(_keyThemes, _themes);
  }

  @override
  Future<void> saveAppSetting(AppSetting entity) async {
    if (!_canUseStorage) return;
    _settings.add(entity);
    await _persistList(_keySettings, _settings);
  }

  @override
  Future<void> saveSyncState(SyncState entity) async {
    if (!_canUseStorage) return;
    _syncStates.add(entity);
    await _persistList(_keySyncStates, _syncStates);
  }

  @override
  Future<void> saveOfflineState(OfflineState entity) async {
    if (!_canUseStorage) return;
    _offlineStates.add(entity);
    await _persistList(_keyOfflineStates, _offlineStates);
  }

  @override
  Future<void> saveAppError(AppError entity) async {
    if (!_canUseStorage) return;
    _appErrors.add(entity);
    await _persistList(_keyAppErrors, _appErrors);
  }

  @override
  Future<void> saveRecoveryState(RecoveryState entity) async {
    if (!_canUseStorage) return;
    _recoveryStates.add(entity);
    await _persistList(_keyRecoveryStates, _recoveryStates);
  }

  @override
  Future<void> saveSubscriptionPlan(SubscriptionPlanEntity entity) async {
    if (!_canUseStorage) return;
    _subscriptionPlans.add(entity);
    await _persistList(_keySubscriptionPlans, _subscriptionPlans);
  }

  @override
  Future<void> savePrivacyPolicy(PrivacyPolicy entity) async {
    if (!_canUseStorage) return;
    _privacyPolicies.add(entity);
    await _persistList(_keyPrivacyPolicies, _privacyPolicies);
  }

  @override
  Future<void> saveHealthCheck(HealthCheckResult entity) async {
    if (!_canUseStorage) return;
    _healthChecks.add(entity);
    await _persistList(_keyHealthChecks, _healthChecks);
  }
}
