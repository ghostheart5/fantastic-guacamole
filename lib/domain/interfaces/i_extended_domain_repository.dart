import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';

/// CHRONOSPARK-CLASS: EXPERIMENTAL | Feature: SI Console / extended domain
///
/// Backs the persisted extended-domain records. Implemented by
/// ExtendedDomainService in lib/state.
abstract class IExtendedDomainRepository {
  Future<void> initialize();

  List<PlannerMessage> getPlannerMessages();
  List<SiQuery> getSiQueries();
  List<ReflectionEntry> getReflectionEntries();
  List<AnalyticsMetric> getAnalyticsMetrics();
  List<AppSetting> getSettings();

  Future<void> savePlannerMessage(PlannerMessage entity);
  Future<void> saveSiQuery(SiQuery entity);
  Future<void> saveReflectionEntry(ReflectionEntry entity);
  Future<void> saveAnalyticsMetric(AnalyticsMetric entity);
  Future<void> saveAppSetting(AppSetting entity);
}
