import 'dart:convert';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/analytics/global_metrics.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/features/identity/services/identity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class GlobalAggregationService {
  GlobalAggregationService({
    required sb.SupabaseClient client,
    required IdentityServiceContract identity,
  })  : _client = client, // ignore: prefer_initializing_formals
        _identity = identity; // ignore: prefer_initializing_formals

  final sb.SupabaseClient _client;
  final IdentityServiceContract _identity;

  static const _kCacheKey = 'global_metrics_cache';
  static const _kCacheTsKey = 'global_metrics_cache_ts';
  static const _kTable = 'user_daily_metrics';
  static const _kCacheMaxAgeSeconds = 86400;

  Future<void> push(Map<String, dynamic> dailySnapshot) async {
    if (!Env.isSupabaseConfigured) return;
    try {
      final deviceId = await _identity.ensureIdentity();
      await _client.from(_kTable).upsert({
        'device_id': deviceId,
        'date': dailySnapshot['date'],
        'focus_sessions': dailySnapshot['focus_sessions'],
        'focus_completed': dailySnapshot['focus_completed'],
        'tasks_created': dailySnapshot['tasks_created'],
        'tasks_completed': dailySnapshot['tasks_completed'],
        'total_focus_seconds': dailySnapshot['total_focus_seconds'],
        'momentum_peak': dailySnapshot['momentum_peak'],
      }, onConflict: 'device_id,date');
    } catch (e) {
      Logger.error('GlobalAggregationService.push failed', e);
    }
  }

  Future<GlobalMetrics> fetchGlobalMetrics() async {
    final cached = _loadCache();
    if (cached != null) return cached;
    if (!Env.isSupabaseConfigured) return GlobalMetrics.empty();
    try {
      final data = await _client
          .from(_kTable)
          .select()
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
    final tsStr = SharedPrefsService.load(_kCacheTsKey);
    if (tsStr == null) return null;
    final ts = int.tryParse(tsStr);
    if (ts == null) return null;
    final age = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - ts;
    if (age > _kCacheMaxAgeSeconds) return null;
    final raw = SharedPrefsService.load(_kCacheKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return GlobalMetrics(
        avgFocusCompletionRate:
            (json['avgFocusCompletionRate'] as num?)?.toDouble() ?? 0,
        avgTaskCompletionRate:
            (json['avgTaskCompletionRate'] as num?)?.toDouble() ?? 0,
        avgMomentumPeak: (json['avgMomentumPeak'] as num?)?.toDouble() ?? 0,
        avgSessionDuration:
            (json['avgSessionDuration'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(GlobalMetrics metrics) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await SharedPrefsService.save(_kCacheTsKey, ts.toString());
    await SharedPrefsService.save(
      _kCacheKey,
      jsonEncode({
        'avgFocusCompletionRate': metrics.avgFocusCompletionRate,
        'avgTaskCompletionRate': metrics.avgTaskCompletionRate,
        'avgMomentumPeak': metrics.avgMomentumPeak,
        'avgSessionDuration': metrics.avgSessionDuration,
      }),
    );
  }
}
