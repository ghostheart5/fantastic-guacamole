import 'dart:convert';

import 'package:fantastic_guacamole/domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExtendedDomainService implements IExtendedDomainRepository {
  ExtendedDomainService();

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

  SharedPreferences? _prefs;
  bool _initialized = false;

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
    if (_initialized) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _hydrateState();
    _initialized = true;
  }

  void _hydrateState() {
    final SharedPreferences prefs = _prefs!;

    _coachMessages
      ..clear()
      ..addAll(
        _decodeEntities<CoachMessage>(
          prefs.getString(_keyCoachMessages),
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
          prefs.getString(_keySiQueries),
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
          prefs.getString(_keyUserIntents),
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
          prefs.getString(_keyJournalEntries),
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
          prefs.getString(_keyAnalyticsMetrics),
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
          prefs.getString(_keyAppNotifications),
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
          prefs.getString(_keyRewards),
          (Map<String, dynamic> json) =>
              Reward(id: json['id'] as String, label: json['label'] as String?),
        ),
      );
    _themes
      ..clear()
      ..addAll(
        _decodeEntities<AppTheme>(
          prefs.getString(_keyThemes),
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
          prefs.getString(_keySettings),
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
          prefs.getString(_keySyncStates),
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
          prefs.getString(_keyOfflineStates),
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
          prefs.getString(_keyAppErrors),
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
          prefs.getString(_keyRecoveryStates),
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
          prefs.getString(_keySubscriptionPlans),
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
          prefs.getString(_keyPrivacyPolicies),
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
          prefs.getString(_keyHealthChecks),
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
    final List<dynamic> decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) => parser(
            item.map<String, dynamic>(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _persistList(
    String key,
    Iterable<LightweightEntity> entities,
  ) async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return;
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
    await prefs.setString(key, encoded);
  }

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
    _coachMessages.add(entity);
    await _persistList(_keyCoachMessages, _coachMessages);
  }

  @override
  Future<void> saveSiQuery(SiQuery entity) async {
    _siQueries.add(entity);
    await _persistList(_keySiQueries, _siQueries);
  }

  @override
  Future<void> saveUserIntent(UserIntent entity) async {
    _userIntents.add(entity);
    await _persistList(_keyUserIntents, _userIntents);
  }

  @override
  Future<void> saveJournalEntry(JournalEntry entity) async {
    _journalEntries.add(entity);
    await _persistList(_keyJournalEntries, _journalEntries);
  }

  @override
  Future<void> saveAnalyticsMetric(AnalyticsMetric entity) async {
    _analyticsMetrics.add(entity);
    await _persistList(_keyAnalyticsMetrics, _analyticsMetrics);
  }

  @override
  Future<void> saveAppNotification(AppNotification entity) async {
    _appNotifications.add(entity);
    await _persistList(_keyAppNotifications, _appNotifications);
  }

  @override
  Future<void> saveReward(Reward entity) async {
    _rewards.add(entity);
    await _persistList(_keyRewards, _rewards);
  }

  @override
  Future<void> saveAppTheme(AppTheme entity) async {
    _themes.add(entity);
    await _persistList(_keyThemes, _themes);
  }

  @override
  Future<void> saveAppSetting(AppSetting entity) async {
    _settings.add(entity);
    await _persistList(_keySettings, _settings);
  }

  @override
  Future<void> saveSyncState(SyncState entity) async {
    _syncStates.add(entity);
    await _persistList(_keySyncStates, _syncStates);
  }

  @override
  Future<void> saveOfflineState(OfflineState entity) async {
    _offlineStates.add(entity);
    await _persistList(_keyOfflineStates, _offlineStates);
  }

  @override
  Future<void> saveAppError(AppError entity) async {
    _appErrors.add(entity);
    await _persistList(_keyAppErrors, _appErrors);
  }

  @override
  Future<void> saveRecoveryState(RecoveryState entity) async {
    _recoveryStates.add(entity);
    await _persistList(_keyRecoveryStates, _recoveryStates);
  }

  @override
  Future<void> saveSubscriptionPlan(SubscriptionPlanEntity entity) async {
    _subscriptionPlans.add(entity);
    await _persistList(_keySubscriptionPlans, _subscriptionPlans);
  }

  @override
  Future<void> savePrivacyPolicy(PrivacyPolicy entity) async {
    _privacyPolicies.add(entity);
    await _persistList(_keyPrivacyPolicies, _privacyPolicies);
  }

  @override
  Future<void> saveHealthCheck(HealthCheckResult entity) async {
    _healthChecks.add(entity);
    await _persistList(_keyHealthChecks, _healthChecks);
  }
}
