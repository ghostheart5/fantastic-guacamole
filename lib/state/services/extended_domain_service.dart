import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/extended_domain_entities.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_extended_domain_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';

class ExtendedDomainService implements IExtendedDomainRepository {
  ExtendedDomainService(this._preferences);

  static const String _keyPlannerMessages = 'extended_domain.planner_messages';
  static const String _keySiQueries = 'extended_domain.si_queries';
  static const String _keyReflectionEntries =
      'extended_domain.reflection_entries';
  static const String _keyAnalyticsMetrics =
      'extended_domain.analytics_metrics';
  static const String _keySettings = 'extended_domain.settings';

  final SharedPrefsStore _preferences;
  Future<void>? _initialization;

  final List<PlannerMessage> _plannerMessages = <PlannerMessage>[];
  final List<SiQuery> _siQueries = <SiQuery>[];
  final List<ReflectionEntry> _reflectionEntries = <ReflectionEntry>[];
  final List<AnalyticsMetric> _analyticsMetrics = <AnalyticsMetric>[];
  final List<AppSetting> _settings = <AppSetting>[];

  @override
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _preferences.init();

    _replaceAll(
      _plannerMessages,
      _decodeEntities<PlannerMessage>(
        _preferences.load(_keyPlannerMessages),
        (Map<String, dynamic> json) => PlannerMessage(
          id: json['id'] as String,
          label: json['label'] as String?,
        ),
      ),
    );
    _replaceAll(
      _siQueries,
      _decodeEntities<SiQuery>(
        _preferences.load(_keySiQueries),
        (Map<String, dynamic> json) =>
            SiQuery(id: json['id'] as String, label: json['label'] as String?),
      ),
    );
    _replaceAll(
      _reflectionEntries,
      _decodeEntities<ReflectionEntry>(
        _preferences.load(_keyReflectionEntries),
        (Map<String, dynamic> json) => ReflectionEntry(
          id: json['id'] as String,
          label: json['label'] as String?,
        ),
      ),
    );
    _replaceAll(
      _analyticsMetrics,
      _decodeEntities<AnalyticsMetric>(
        _preferences.load(_keyAnalyticsMetrics),
        (Map<String, dynamic> json) => AnalyticsMetric(
          id: json['id'] as String,
          label: json['label'] as String?,
        ),
      ),
    );
    _replaceAll(
      _settings,
      _decodeEntities<AppSetting>(
        _preferences.load(_keySettings),
        (Map<String, dynamic> json) => AppSetting(
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
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List<dynamic>) {
        return <T>[];
      }
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
    } on Object {
      return <T>[];
    }
  }

  void _replaceAll<T>(List<T> target, Iterable<T> values) {
    target
      ..clear()
      ..addAll(values);
  }

  Future<void> _persistList(
    String key,
    Iterable<LightweightEntity> entities,
  ) async {
    await _preferences.save(
      key,
      jsonEncode(
        entities
            .map(
              (LightweightEntity entity) => <String, dynamic>{
                'id': entity.id,
                'label': entity.label,
              },
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  List<PlannerMessage> getPlannerMessages() =>
      List<PlannerMessage>.unmodifiable(_plannerMessages);

  @override
  List<SiQuery> getSiQueries() => List<SiQuery>.unmodifiable(_siQueries);

  @override
  List<ReflectionEntry> getReflectionEntries() =>
      List<ReflectionEntry>.unmodifiable(_reflectionEntries);

  @override
  List<AnalyticsMetric> getAnalyticsMetrics() =>
      List<AnalyticsMetric>.unmodifiable(_analyticsMetrics);

  @override
  List<AppSetting> getSettings() => List<AppSetting>.unmodifiable(_settings);

  @override
  Future<void> savePlannerMessage(PlannerMessage entity) async {
    _plannerMessages.add(entity);
    await _persistList(_keyPlannerMessages, _plannerMessages);
  }

  @override
  Future<void> saveSiQuery(SiQuery entity) async {
    _siQueries.add(entity);
    await _persistList(_keySiQueries, _siQueries);
  }

  @override
  Future<void> saveReflectionEntry(ReflectionEntry entity) async {
    _reflectionEntries.add(entity);
    await _persistList(_keyReflectionEntries, _reflectionEntries);
  }

  @override
  Future<void> saveAnalyticsMetric(AnalyticsMetric entity) async {
    _analyticsMetrics.add(entity);
    await _persistList(_keyAnalyticsMetrics, _analyticsMetrics);
  }

  @override
  Future<void> saveAppSetting(AppSetting entity) async {
    _settings.add(entity);
    await _persistList(_keySettings, _settings);
  }
}
