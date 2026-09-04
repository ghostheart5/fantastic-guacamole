import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/system/analytics/global_metrics.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class GlobalAggregationService {
  GlobalAggregationService({
    required sb.SupabaseClient? client,
    required Future<String> Function() ensureIdentity,
    required SharedPrefsStore preferences,
  }) : _client = client, // ignore: prefer_initializing_formals
       _ensureIdentity = ensureIdentity, // ignore: prefer_initializing_formals
       _preferences = preferences; // ignore: prefer_initializing_formals

  final sb.SupabaseClient? _client;
  final Future<String> Function() _ensureIdentity;
  final SharedPrefsStore _preferences;

  static const _kCacheKey = 'global_metrics_cache';
  static const _kCacheTsKey = 'global_metrics_cache_ts';
  static const _kTable = 'user_daily_metrics';
  static const _kCacheMaxAgeSeconds = 86400;

  Future<void> push(Map<String, dynamic> dailySnapshot) async {
    // Consent gate. This is the most privacy-sensitive call in the app — it
    // uploads a device id, a user id and behavioural counters — and it was the
    // only analytics path that did not consult the analytics flag at all.
    if (!Env.enableAnalytics) {
      return;
    }
    if (!await _cloudSyncEnabled()) {
      return;
    }
    final sb.SupabaseClient? client = _client;
    final String? userId = client?.auth.currentUser?.id;
    if (!Env.isSupabaseConfigured || client == null || userId == null) {
      return;
    }
    try {
      final deviceId = sha256
          .convert(utf8.encode('${await _ensureIdentity()}:$userId'))
          .toString()
          .substring(0, 32);
      await client.from(_kTable).upsert({
        'device_id': deviceId,
        'user_id': userId,
        'date': dailySnapshot['date'],
        'tasks_created': dailySnapshot['tasks_created'],
        'tasks_completed': dailySnapshot['tasks_completed'],
        'momentum_peak': dailySnapshot['momentum_peak'],
      }, onConflict: 'user_id,date');
    } catch (e) {
      Logger.error('GlobalAggregationService.push failed', e);
    }
  }

  Future<GlobalMetrics> fetchGlobalMetrics() async {
    if (!await _cloudSyncEnabled()) {
      return GlobalMetrics.empty();
    }
    final cached = _loadCache();
    if (cached != null) return cached;
    final sb.SupabaseClient? client = _client;
    if (!Env.isSupabaseConfigured ||
        client == null ||
        client.auth.currentUser == null) {
      return GlobalMetrics.empty();
    }
    final String userId = client.auth.currentUser!.id;
    try {
      final data = await client
          .from(_kTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1000);
      final rows = (data as List).cast<Map<String, dynamic>>();
      final metrics = GlobalMetrics.fromRows(rows);
      await _saveCache(metrics);
      return metrics;
    } catch (e) {
      Logger.error('GlobalAggregationService.fetchGlobalMetrics failed', e);
      return GlobalMetrics.empty();
    }
  }

  GlobalMetrics? _loadCache() {
    final tsStr = _preferences.load(_kCacheTsKey);
    if (tsStr == null) return null;
    final ts = int.tryParse(tsStr);
    if (ts == null) return null;
    final age = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - ts;
    if (age > _kCacheMaxAgeSeconds) return null;
    final raw = _preferences.load(_kCacheKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return GlobalMetrics(
        avgTaskCompletionRate:
            (json['avgTaskCompletionRate'] as num?)?.toDouble() ?? 0,
        avgMomentumPeak: (json['avgMomentumPeak'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(GlobalMetrics metrics) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _preferences.save(_kCacheTsKey, ts.toString());
    await _preferences.save(
      _kCacheKey,
      jsonEncode({
        'avgTaskCompletionRate': metrics.avgTaskCompletionRate,
        'avgMomentumPeak': metrics.avgMomentumPeak,
      }),
    );
  }

  Future<bool> _cloudSyncEnabled() async {
    try {
      await _preferences.init();
      return _preferences.load('cloud_sync_enabled_v1') == 'true';
    } on Object catch (_, stackTrace) {
      Logger.recordDiagnostic(
        code: AppDiagnosticCode.globalAggregationConsentScopeUnavailable,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
