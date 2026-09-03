import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Analytics
///
/// Extended-domain read. Registered as getAnalyticsMetricsUseCaseProvider.
class GetAnalyticsMetrics {
  const GetAnalyticsMetrics(this._repository);

  final IExtendedDomainRepository _repository;

  List<AnalyticsMetric> call() => _repository.getAnalyticsMetrics();
}
