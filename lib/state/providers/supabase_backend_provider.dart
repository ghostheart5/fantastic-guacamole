import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum SupabaseHealthBadge {
  healthy,
  connectivityIssue,
  sessionMissing,
  policyRestricted,
}

class SupabaseBackendHealth {
  const SupabaseBackendHealth({
    required this.configured,
    required this.initialized,
    required this.authenticated,
    required this.databaseReachable,
    required this.storageReachable,
    required this.realtimeConfigured,
    required this.badge,
    required this.message,
  });

  final bool configured;
  final bool initialized;
  final bool authenticated;
  final bool databaseReachable;
  final bool storageReachable;
  final bool realtimeConfigured;
  final SupabaseHealthBadge badge;
  final String message;

  bool get isHealthy =>
      configured && initialized && databaseReachable && storageReachable;

  String get badgeLabel {
    switch (badge) {
      case SupabaseHealthBadge.healthy:
        return 'Healthy';
      case SupabaseHealthBadge.connectivityIssue:
        return 'Connectivity Issue';
      case SupabaseHealthBadge.sessionMissing:
        return 'Session Missing';
      case SupabaseHealthBadge.policyRestricted:
        return 'Policy Restricted';
    }
  }
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
      badge: SupabaseHealthBadge.connectivityIssue,
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
      badge: SupabaseHealthBadge.connectivityIssue,
      message: 'Supabase is configured but not initialized in this runtime.',
    );
  }

  final bool authenticated = client.auth.currentSession != null;

  bool databaseReachable = false;
  bool storageReachable = false;
  bool databasePermissionDenied = false;
  bool storagePermissionDenied = false;

  try {
    await client.from('user_daily_metrics').select('date').limit(1);
    databaseReachable = true;
  } catch (error) {
    databasePermissionDenied = _looksLikePermissionDenied(error);
    if (databasePermissionDenied) {
      databaseReachable = true;
    }
    Logger.warn('Supabase database health check failed: $error');
  }

  try {
    final String uid = client.auth.currentUser?.id ?? 'anonymous';
    await client.storage.from('chronospark-sync').list(path: '$uid/backup');
    storageReachable = true;
  } catch (error) {
    storagePermissionDenied = _looksLikePermissionDenied(error);
    if (storagePermissionDenied) {
      storageReachable = true;
    }
    Logger.warn('Supabase storage health check failed: $error');
  }

  final bool realtimeConfigured = client.realtime.accessToken != null;
  final bool policyRestricted =
      databasePermissionDenied || storagePermissionDenied;
  final bool sessionMissing = !authenticated;
  final bool connectivityIssue = !databaseReachable || !storageReachable;

  final SupabaseHealthBadge badge;
  if (policyRestricted) {
    badge = SupabaseHealthBadge.policyRestricted;
  } else if (sessionMissing) {
    badge = SupabaseHealthBadge.sessionMissing;
  } else if (connectivityIssue) {
    badge = SupabaseHealthBadge.connectivityIssue;
  } else {
    badge = SupabaseHealthBadge.healthy;
  }

  final String message;
  if (policyRestricted) {
    final List<String> blockedResources = <String>[];
    if (databasePermissionDenied) {
      blockedResources.add('database');
    }
    if (storagePermissionDenied) {
      blockedResources.add('storage');
    }
    final String blocked = blockedResources.join(' and ');
    message =
        'Supabase is reachable, but $blocked access is blocked by current role policies/permissions.';
  } else if (databaseReachable && storageReachable) {
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
    badge: badge,
    message: message,
  );
});

bool _looksLikePermissionDenied(Object error) {
  final String text = error.toString().toLowerCase();
  return text.contains('42501') ||
      text.contains('permission denied') ||
      text.contains('not allowed') ||
      text.contains('forbidden');
}

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
