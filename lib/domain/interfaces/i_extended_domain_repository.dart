import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';

abstract class IExtendedDomainRepository {
  Future<void> initialize();

  List<CoachMessage> getCoachMessages();
  List<SiQuery> getSiQueries();
  List<UserIntent> getUserIntents();
  List<JournalEntry> getJournalEntries();
  List<AnalyticsMetric> getAnalyticsMetrics();
  List<AppNotification> getAppNotifications();
  List<Reward> getRewards();
  List<AppTheme> getThemes();
  List<AppSetting> getSettings();
  List<SyncState> getSyncStates();
  List<OfflineState> getOfflineStates();
  List<AppError> getAppErrors();
  List<RecoveryState> getRecoveryStates();
  List<SubscriptionPlanEntity> getSubscriptionPlans();
  List<PrivacyPolicy> getPrivacyPolicies();
  List<HealthCheckResult> getHealthChecks();

  Future<void> saveCoachMessage(CoachMessage entity);
  Future<void> saveSiQuery(SiQuery entity);
  Future<void> saveUserIntent(UserIntent entity);
  Future<void> saveJournalEntry(JournalEntry entity);
  Future<void> saveAnalyticsMetric(AnalyticsMetric entity);
  Future<void> saveAppNotification(AppNotification entity);
  Future<void> saveReward(Reward entity);
  Future<void> saveAppTheme(AppTheme entity);
  Future<void> saveAppSetting(AppSetting entity);
  Future<void> saveSyncState(SyncState entity);
  Future<void> saveOfflineState(OfflineState entity);
  Future<void> saveAppError(AppError entity);
  Future<void> saveRecoveryState(RecoveryState entity);
  Future<void> saveSubscriptionPlan(SubscriptionPlanEntity entity);
  Future<void> savePrivacyPolicy(PrivacyPolicy entity);
  Future<void> saveHealthCheck(HealthCheckResult entity);
}
