import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseBackendHealth {
  const SupabaseBackendHealth({
    required this.configured,
    required this.initialized,
    required this.authenticated,
    required this.databaseReachable,
    required this.storageReachable,
    required this.realtimeConfigured,
    required this.message,
  });

  final bool configured;
  final bool initialized;
  final bool authenticated;
  final bool databaseReachable;
  final bool storageReachable;
  final bool realtimeConfigured;
  final String message;

  bool get isHealthy =>
      configured && initialized && databaseReachable && storageReachable;
}

final supabaseBackendHealthProvider = FutureProvider<SupabaseBackendHealth>((
  ref,
) async {
  final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
  if (!Env.isSupabaseConfigured) {
    return const SupabaseBackendHealth(
      configured: false,
      initialized: false,
      authenticated: false,
      databaseReachable: false,
      storageReachable: false,
      realtimeConfigured: false,
      message:
          'Supabase is not configured. Provide CHRONOSPARK_SUPABASE_URL and CHRONOSPARK_SUPABASE_ANON_KEY.',
    );
  }

  if (client == null) {
    return const SupabaseBackendHealth(
      configured: true,
      initialized: false,
      authenticated: false,
      databaseReachable: false,
      storageReachable: false,
      realtimeConfigured: false,
      message: 'Supabase is configured but not initialized in this runtime.',
    );
  }

  final bool authenticated = client.auth.currentSession != null;

  bool databaseReachable = false;
  bool storageReachable = false;

  try {
    await client.from('user_daily_metrics').select('date').limit(1);
    databaseReachable = true;
  } catch (error) {
    Logger.warn('Supabase database health check failed: $error');
  }

  try {
    final String uid = client.auth.currentUser?.id ?? 'anonymous';
    await client.storage.from('chronospark-sync').list(path: '$uid/backup');
    storageReachable = true;
  } catch (error) {
    Logger.warn('Supabase storage health check failed: $error');
  }

  final bool realtimeConfigured = client.realtime.accessToken != null;

  final String message;
  if (databaseReachable && storageReachable) {
    message = 'Supabase backend is reachable.';
  } else if (!databaseReachable && !storageReachable) {
    message =
        'Supabase database and storage are not reachable with current credentials/policies.';
  } else if (!databaseReachable) {
    message =
        'Supabase database is not reachable with current credentials/policies.';
  } else {
    message =
        'Supabase storage is not reachable with current credentials/policies.';
  }

  return SupabaseBackendHealth(
    configured: true,
    initialized: true,
    authenticated: authenticated,
    databaseReachable: databaseReachable,
    storageReachable: storageReachable,
    realtimeConfigured: realtimeConfigured,
    message: message,
  );
});

final supabaseMetricsRealtimeProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final sb.SupabaseClient? client = ref.watch(supabaseClientProvider);
      if (!Env.isSupabaseConfigured || client == null) {
        return Stream<List<Map<String, dynamic>>>.value(
          const <Map<String, dynamic>>[],
        );
      }

      return client
          .from('user_daily_metrics')
          .stream(primaryKey: const <String>['device_id', 'date'])
          .order('created_at')
          .map(
            (rows) => rows
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false),
          );
    });
