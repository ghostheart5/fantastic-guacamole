import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

enum ValidationState { pass, warning, fail }

enum CoreEntityStatus { supabaseRoundtrip, localOnly, broken, notImplemented }

extension CoreEntityStatusLabel on CoreEntityStatus {
  String get label {
    switch (this) {
      case CoreEntityStatus.supabaseRoundtrip:
        return 'SUPABASE ROUNDTRIP';
      case CoreEntityStatus.localOnly:
        return 'LOCAL ONLY';
      case CoreEntityStatus.broken:
        return 'BROKEN';
      case CoreEntityStatus.notImplemented:
        return 'NOT IMPLEMENTED';
    }
  }
}

class ValidationItem {
  const ValidationItem({
    required this.category,
    required this.check,
    required this.state,
    required this.message,
    this.evidence = const <String>[],
    this.details = const <String, Object?>{},
  });

  final String category;
  final String check;
  final ValidationState state;
  final String message;
  final List<String> evidence;
  final Map<String, Object?> details;
}

class CoreEntityAuditItem {
  const CoreEntityAuditItem({
    required this.feature,
    required this.table,
    required this.status,
    required this.localRepositoryFile,
    required this.supabaseRepositoryFile,
    required this.providerFile,
    required this.uiFile,
    required this.createPath,
    required this.readPath,
    required this.updatePath,
    required this.deletePath,
    required this.restartPersistence,
    required this.loginLogoutPersistence,
    required this.supabasePersistenceStatus,
    required this.localOnlyFallback,
    required this.evidence,
  });

  final String feature;
  final String table;
  final CoreEntityStatus status;
  final String localRepositoryFile;
  final String supabaseRepositoryFile;
  final String providerFile;
  final String uiFile;
  final String createPath;
  final String readPath;
  final String updatePath;
  final String deletePath;
  final String restartPersistence;
  final String loginLogoutPersistence;
  final String supabasePersistenceStatus;
  final bool localOnlyFallback;
  final List<String> evidence;
}

class SupabaseRoundtripValidationReport {
  const SupabaseRoundtripValidationReport({
    required this.generatedAt,
    required this.userId,
    required this.items,
    required this.coreEntityAudit,
  });

  final DateTime generatedAt;
  final String? userId;
  final List<ValidationItem> items;
  final List<CoreEntityAuditItem> coreEntityAudit;

  bool get hasFailure =>
      items.any((ValidationItem i) => i.state == ValidationState.fail);

  bool get hasWarning =>
      items.any((ValidationItem i) => i.state == ValidationState.warning);
}

class SupabaseRoundtripValidator {
  SupabaseRoundtripValidator({sb.SupabaseClient? client})
    : _client = client ?? sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  Future<SupabaseRoundtripValidationReport> run({
    bool attemptStorageDelete = true,
  }) async {
    final List<ValidationItem> items = <ValidationItem>[];
    items.addAll(await _validateAuth());
    items.addAll(
      await _validateStorage(attemptStorageDelete: attemptStorageDelete),
    );
    items.addAll(await _validateUserDailyMetrics());
    items.addAll(await _validateMonetizationReads());

    return SupabaseRoundtripValidationReport(
      generatedAt: DateTime.now().toUtc(),
      userId: _client.auth.currentUser?.id,
      items: items,
      coreEntityAudit: _coreEntityAuditItems,
    );
  }

  Future<List<ValidationItem>> _validateAuth() async {
    final List<ValidationItem> items = <ValidationItem>[];
    final sb.User? user = _client.auth.currentUser;
    final sb.Session? session = _client.auth.currentSession;
    final String? token = session?.accessToken;

    items.add(
      ValidationItem(
        category: 'AUTH',
        check: 'current user exists',
        state: user != null ? ValidationState.pass : ValidationState.fail,
        message: user != null
            ? 'Authenticated user found.'
            : 'No authenticated user.',
        evidence: const <String>['supabase.auth.currentUser'],
      ),
    );

    items.add(
      ValidationItem(
        category: 'AUTH',
        check: 'session exists',
        state: session != null ? ValidationState.pass : ValidationState.fail,
        message: session != null
            ? 'Active session found.'
            : 'No active session.',
        evidence: const <String>['supabase.auth.currentSession'],
      ),
    );

    items.add(
      ValidationItem(
        category: 'AUTH',
        check: 'JWT/token available',
        state: token != null && token.trim().isNotEmpty
            ? ValidationState.pass
            : ValidationState.fail,
        message: token != null && token.trim().isNotEmpty
            ? 'JWT token is available.'
            : 'JWT token is missing.',
        evidence: const <String>['supabase.auth.currentSession.accessToken'],
      ),
    );

    if (user == null) {
      items.add(
        const ValidationItem(
          category: 'AUTH',
          check: 'profile row exists in profiles table',
          state: ValidationState.fail,
          message: 'Skipped because there is no authenticated user.',
          evidence: <String>['public.profiles'],
        ),
      );
      items.add(
        const ValidationItem(
          category: 'AUTH',
          check: 'profile id matches auth.uid',
          state: ValidationState.fail,
          message: 'Skipped because there is no authenticated user.',
          evidence: <String>['public.profiles.id == auth.uid()'],
        ),
      );
      return items;
    }

    try {
      final dynamic row = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (row is! Map<String, dynamic>) {
        items.add(
          const ValidationItem(
            category: 'AUTH',
            check: 'profile row exists in profiles table',
            state: ValidationState.fail,
            message: 'No profile row found for current auth user.',
            evidence: <String>['public.profiles'],
          ),
        );
        items.add(
          const ValidationItem(
            category: 'AUTH',
            check: 'profile id matches auth.uid',
            state: ValidationState.fail,
            message:
                'Cannot verify id equality because profile row is missing.',
            evidence: <String>['public.profiles.id == auth.uid()'],
          ),
        );
      } else {
        final String? profileId = row['id']?.toString();
        final bool matches = profileId == user.id;
        items.add(
          ValidationItem(
            category: 'AUTH',
            check: 'profile row exists in profiles table',
            state: ValidationState.pass,
            message: 'Profile row exists for current auth user.',
            evidence: const <String>['public.profiles'],
            details: <String, Object?>{'profile_id': profileId},
          ),
        );
        items.add(
          ValidationItem(
            category: 'AUTH',
            check: 'profile id matches auth.uid',
            state: matches ? ValidationState.pass : ValidationState.fail,
            message: matches
                ? 'Profile id matches auth.uid.'
                : 'Profile id does not match auth.uid.',
            evidence: const <String>['public.profiles.id == auth.uid()'],
            details: <String, Object?>{
              'profile_id': profileId,
              'auth_uid': user.id,
            },
          ),
        );
      }
    } on Object catch (error) {
      items.add(
        ValidationItem(
          category: 'AUTH',
          check: 'profile row exists in profiles table',
          state: ValidationState.fail,
          message: _looksLikeMissingRelation(error)
              ? 'profiles table appears missing at runtime.'
              : 'Failed to read profiles row: $error',
          evidence: const <String>['public.profiles'],
        ),
      );
      items.add(
        const ValidationItem(
          category: 'AUTH',
          check: 'profile id matches auth.uid',
          state: ValidationState.fail,
          message:
              'Cannot verify profile id match because profiles query failed.',
          evidence: <String>['public.profiles.id == auth.uid()'],
        ),
      );
    }

    return items;
  }

  Future<List<ValidationItem>> _validateStorage({
    required bool attemptStorageDelete,
  }) async {
    final List<ValidationItem> items = <ValidationItem>[];
    final sb.User? user = _client.auth.currentUser;
    if (user == null) {
      return const <ValidationItem>[
        ValidationItem(
          category: 'STORAGE',
          check: 'upload/download/delete round-trip',
          state: ValidationState.fail,
          message: 'Skipped because there is no authenticated user.',
          evidence: <String>['storage bucket: chronospark-sync'],
        ),
      ];
    }

    final String now = DateTime.now().toUtc().toIso8601String();
    final String safeNow = now.replaceAll(':', '-');
    final String path = '${user.id}/validation/roundtrip-$safeNow.json';
    final Map<String, dynamic> payload = <String, dynamic>{
      'uid': user.id,
      'nonce': DateTime.now().microsecondsSinceEpoch,
      'generated_at_utc': now,
      'kind': 'supabase_roundtrip_validation',
    };
    final String encoded = jsonEncode(payload);

    bool uploaded = false;
    try {
      await _client.storage
          .from('chronospark-sync')
          .uploadBinary(
            path,
            utf8.encode(encoded),
            fileOptions: const sb.FileOptions(
              upsert: true,
              cacheControl: '0',
              contentType: 'application/json',
            ),
          );
      uploaded = true;
      items.add(
        ValidationItem(
          category: 'STORAGE',
          check: 'upload test object to chronospark-sync',
          state: ValidationState.pass,
          message: 'Upload succeeded.',
          details: <String, Object?>{'path': path},
          evidence: const <String>[
            'storage.from(chronospark-sync).uploadBinary',
          ],
        ),
      );
    } on Object catch (error) {
      items.add(
        ValidationItem(
          category: 'STORAGE',
          check: 'upload test object to chronospark-sync',
          state: ValidationState.fail,
          message: 'Upload failed: $error',
          details: <String, Object?>{'path': path},
          evidence: const <String>[
            'storage.from(chronospark-sync).uploadBinary',
          ],
        ),
      );
    }

    if (uploaded) {
      try {
        final List<int> bytes = await _client.storage
            .from('chronospark-sync')
            .download(path);
        final String downloaded = utf8.decode(bytes);
        final bool matches = downloaded == encoded;
        items.add(
          ValidationItem(
            category: 'STORAGE',
            check: 'download uploaded object and verify contents',
            state: matches ? ValidationState.pass : ValidationState.fail,
            message: matches
                ? 'Downloaded object matches uploaded payload.'
                : 'Downloaded object does not match uploaded payload.',
            details: <String, Object?>{'path': path},
            evidence: const <String>['storage.from(chronospark-sync).download'],
          ),
        );
      } on Object catch (error) {
        items.add(
          ValidationItem(
            category: 'STORAGE',
            check: 'download uploaded object and verify contents',
            state: ValidationState.fail,
            message: 'Download failed: $error',
            details: <String, Object?>{'path': path},
            evidence: const <String>['storage.from(chronospark-sync).download'],
          ),
        );
      }
    }

    if (attemptStorageDelete && uploaded) {
      try {
        await _client.storage.from('chronospark-sync').remove(<String>[path]);
        items.add(
          ValidationItem(
            category: 'STORAGE',
            check: 'delete validation object if policy allows',
            state: ValidationState.pass,
            message: 'Validation object deleted.',
            details: <String, Object?>{'path': path},
            evidence: const <String>['storage.from(chronospark-sync).remove'],
          ),
        );
      } on Object catch (error) {
        items.add(
          ValidationItem(
            category: 'STORAGE',
            check: 'delete validation object if policy allows',
            state: ValidationState.warning,
            message: 'Delete failed (upload/download still validated): $error',
            details: <String, Object?>{'path': path},
            evidence: const <String>['storage.from(chronospark-sync).remove'],
          ),
        );
      }
    }

    return items;
  }

  Future<List<ValidationItem>> _validateUserDailyMetrics() async {
    final List<ValidationItem> items = <ValidationItem>[];
    final sb.User? user = _client.auth.currentUser;
    if (user == null) {
      return const <ValidationItem>[
        ValidationItem(
          category: 'USER DAILY METRICS',
          check: 'upsert/readback/stream',
          state: ValidationState.fail,
          message: 'Skipped because there is no authenticated user.',
          evidence: <String>['public.user_daily_metrics'],
        ),
      ];
    }

    final String date = DateTime.now()
        .toUtc()
        .toIso8601String()
        .split('T')
        .first;
    final String deviceId = 'roundtrip_validator_${user.id.substring(0, 8)}';
    final Map<String, dynamic> row = <String, dynamic>{
      'device_id': deviceId,
      'date': date,
      'user_id': user.id,
      'tasks_created': 777,
      'tasks_completed': 333,
      'momentum_peak': 0.777,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client
          .from('user_daily_metrics')
          .upsert(row, onConflict: 'user_id,date');
      items.add(
        const ValidationItem(
          category: 'USER DAILY METRICS',
          check: 'upsert validation row',
          state: ValidationState.pass,
          message: 'Upsert succeeded.',
          evidence: <String>['from(user_daily_metrics).upsert'],
        ),
      );
    } on Object catch (error) {
      items.add(
        ValidationItem(
          category: 'USER DAILY METRICS',
          check: 'upsert validation row',
          state: ValidationState.fail,
          message: _looksLikeMissingRelation(error)
              ? 'user_daily_metrics table appears missing at runtime.'
              : 'Upsert failed: $error',
          evidence: const <String>['from(user_daily_metrics).upsert'],
        ),
      );
      return items;
    }

    try {
      final dynamic fetched = await _client
          .from('user_daily_metrics')
          .select(
            'device_id,date,user_id,tasks_created,tasks_completed,momentum_peak',
          )
          .eq('device_id', deviceId)
          .eq('date', date)
          .maybeSingle();

      if (fetched is! Map<String, dynamic>) {
        items.add(
          const ValidationItem(
            category: 'USER DAILY METRICS',
            check: 'read back validation row',
            state: ValidationState.fail,
            message: 'Readback returned no row.',
            evidence: <String>[
              'from(user_daily_metrics).select.eq.maybeSingle',
            ],
          ),
        );
      } else {
        final bool fieldsMatch =
            fetched['device_id']?.toString() == deviceId &&
            fetched['date']?.toString() == date &&
            fetched['user_id']?.toString() == user.id &&
            fetched['tasks_created'] == 777 &&
            fetched['tasks_completed'] == 333;

        items.add(
          ValidationItem(
            category: 'USER DAILY METRICS',
            check: 'read back validation row',
            state: fieldsMatch ? ValidationState.pass : ValidationState.fail,
            message: fieldsMatch
                ? 'Readback row matches expected fields.'
                : 'Readback row fields do not match expected payload.',
            evidence: const <String>[
              'from(user_daily_metrics).select.eq.maybeSingle',
            ],
            details: fetched,
          ),
        );
      }
    } on Object catch (error) {
      items.add(
        ValidationItem(
          category: 'USER DAILY METRICS',
          check: 'read back validation row',
          state: ValidationState.fail,
          message: 'Readback failed: $error',
          evidence: const <String>[
            'from(user_daily_metrics).select.eq.maybeSingle',
          ],
        ),
      );
    }

    try {
      final StreamSubscription<List<Map<String, dynamic>>> subscription =
          _client
              .from('user_daily_metrics')
              .stream(primaryKey: const <String>['device_id', 'date'])
              .listen((_) {});
      await subscription.cancel();
      items.add(
        const ValidationItem(
          category: 'USER DAILY METRICS',
          check: 'create realtime stream without crash',
          state: ValidationState.pass,
          message: 'Realtime stream created and cancelled safely.',
          evidence: <String>['from(user_daily_metrics).stream'],
        ),
      );
    } on Object catch (error) {
      items.add(
        ValidationItem(
          category: 'USER DAILY METRICS',
          check: 'create realtime stream without crash',
          state: ValidationState.fail,
          message: 'Stream creation failed: $error',
          evidence: const <String>['from(user_daily_metrics).stream'],
        ),
      );
    }

    return items;
  }

  Future<List<ValidationItem>> _validateMonetizationReads() async {
    final List<ValidationItem> items = <ValidationItem>[];
    final sb.User? user = _client.auth.currentUser;
    if (user == null) {
      return const <ValidationItem>[
        ValidationItem(
          category: 'MONETIZATION',
          check: 'all monetization reads',
          state: ValidationState.fail,
          message: 'Skipped because there is no authenticated user.',
          evidence: <String>[
            'monetization_subscription_statuses',
            'monetization_wallets',
            'monetization_credit_transactions',
            'monetization_entitlement_events',
          ],
        ),
      ];
    }

    items.add(
      await _readMonetizationSingleton(
        table: 'monetization_subscription_statuses',
        checkName: 'read monetization_subscription_statuses',
        missingRowMessage:
            'No subscription status row found (initialization issue, not table missing).',
        requiredForRelease: false,
      ),
    );

    items.add(
      await _readMonetizationSingleton(
        table: 'monetization_wallets',
        checkName: 'read monetization_wallets',
        missingRowMessage:
            'No wallet row found (initialization issue, not table missing).',
        requiredForRelease: true,
      ),
    );

    items.add(
      await _readMonetizationList(
        table: 'monetization_credit_transactions',
        checkName: 'read monetization_credit_transactions',
        limit: 20,
      ),
    );

    items.add(
      await _readMonetizationList(
        table: 'monetization_entitlement_events',
        checkName: 'read monetization_entitlement_events',
        limit: 20,
      ),
    );

    return items;
  }

  Future<ValidationItem> _readMonetizationSingleton({
    required String table,
    required String checkName,
    required String missingRowMessage,
    required bool requiredForRelease,
  }) async {
    final String userId = _client.auth.currentUser!.id;
    try {
      final dynamic row = await _client
          .from(table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return ValidationItem(
          category: 'MONETIZATION',
          check: checkName,
          state: ValidationState.pass,
          message: 'Read succeeded.',
          evidence: <String>['from($table).select.eq.maybeSingle'],
        );
      }
      return ValidationItem(
        category: 'MONETIZATION',
        check: checkName,
        state: requiredForRelease
            ? ValidationState.warning
            : ValidationState.warning,
        message: missingRowMessage,
        evidence: <String>['from($table).select.eq.maybeSingle'],
      );
    } on Object catch (error) {
      final bool missingRelation = _looksLikeMissingRelation(error);
      return ValidationItem(
        category: 'MONETIZATION',
        check: checkName,
        state: ValidationState.fail,
        message: missingRelation
            ? '$table appears missing at runtime.'
            : 'Read failed: $error',
        evidence: <String>['from($table).select.eq.maybeSingle'],
      );
    }
  }

  Future<ValidationItem> _readMonetizationList({
    required String table,
    required String checkName,
    required int limit,
  }) async {
    final String userId = _client.auth.currentUser!.id;
    try {
      await _client
          .from(table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return ValidationItem(
        category: 'MONETIZATION',
        check: checkName,
        state: ValidationState.pass,
        message: 'Read succeeded.',
        evidence: <String>['from($table).select.eq.order.limit'],
      );
    } on Object catch (error) {
      final bool missingRelation = _looksLikeMissingRelation(error);
      return ValidationItem(
        category: 'MONETIZATION',
        check: checkName,
        state: ValidationState.fail,
        message: missingRelation
            ? '$table appears missing at runtime.'
            : 'Read failed: $error',
        evidence: <String>['from($table).select.eq.order.limit'],
      );
    }
  }

  bool _looksLikeMissingRelation(Object error) {
    final String text = error.toString().toLowerCase();
    return (text.contains('relation') && text.contains('does not exist')) ||
        text.contains('42p01') ||
        text.contains('table not found');
  }

  static const List<CoreEntityAuditItem> _coreEntityAuditItems =
      <CoreEntityAuditItem>[
        CoreEntityAuditItem(
          feature: 'Tasks',
          table: 'tasks',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'lib/data/repositories/task_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/task_provider.dart',
          uiFile: 'lib/features/creator/ui/widgets/creator_entry_lists.dart',
          createPath: 'Yes (local)',
          readPath: 'Yes (local)',
          updatePath: 'Yes (local)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (Hive)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'task_repository.dart:23,49,61,70',
            'task_provider.dart:44',
            'creator_entry_lists.dart:12',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Goals',
          table: 'goals',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'lib/data/repositories/goal_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/goals_provider.dart',
          uiFile: 'lib/features/timeline/ui/timeline_screen.dart',
          createPath: 'Yes (local)',
          readPath: 'Yes (local)',
          updatePath: 'Yes (local)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (Hive)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'goal_repository.dart:18,44,61,70',
            'goals_provider.dart:21',
            'timeline_screen.dart:114',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Habits',
          table: 'habits',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'lib/data/repositories/habit_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/habits_provider.dart',
          uiFile: 'lib/state/providers/momentum_engine_provider.dart',
          createPath: 'Yes (local)',
          readPath: 'Yes (local)',
          updatePath: 'Yes (local toggle)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (Hive)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'habit_repository.dart:40,63',
            'habits_provider.dart:9',
            'momentum_engine_provider.dart:40',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Timeline Events',
          table: 'timeline_events',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'lib/data/repositories/timeline_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/timeline_provider.dart',
          uiFile: 'lib/features/timeline/ui/timeline_screen.dart',
          createPath: 'Yes (local)',
          readPath: 'Yes (local)',
          updatePath: 'Partial (save list)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (SharedPrefs)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'timeline_repository.dart:15,32,41,49',
            'timeline_provider.dart:29',
            'timeline_screen.dart:62',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Notifications',
          table: 'notifications',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile:
              'lib/data/repositories/notifications_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/notification_provider.dart',
          uiFile: 'lib/features/notifications/ui/notification_screen.dart',
          createPath: 'Yes (local + scheduler)',
          readPath: 'Yes (local)',
          updatePath: 'Yes (markRead/cancel)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (SecureStore)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'notifications_repository.dart:29,77,126,145',
            'notification_provider.dart:12',
            'notification_screen.dart:17',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Settings',
          table: 'settings',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'lib/data/repositories/settings_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/settings_ui_provider.dart',
          uiFile: 'lib/features/settings/ui/settings_screen.dart',
          createPath: 'Yes (local save)',
          readPath: 'Yes (local read)',
          updatePath: 'Yes (local overwrite)',
          deletePath: 'No explicit delete path',
          restartPersistence: 'Yes (SharedPrefs)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'settings_repository.dart:15,42',
            'settings_ui_provider.dart:113',
            'settings_screen.dart:30',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Core Values',
          table: 'core_values',
          status: CoreEntityStatus.notImplemented,
          localRepositoryFile: '-',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/core_values_provider.dart',
          uiFile: 'lib/features/si_console/ui/si_console_screen.dart',
          createPath: 'No dedicated persisted create path',
          readPath: 'Derived in-memory from other providers',
          updatePath: 'No dedicated persisted update path',
          deletePath: 'No dedicated delete path',
          restartPersistence: 'Derived/recomputed',
          loginLogoutPersistence: 'Derived/recomputed',
          supabasePersistenceStatus: 'Not implemented in Supabase',
          localOnlyFallback: true,
          evidence: <String>[
            'core_values_provider.dart:13',
            'si_console_screen.dart:450',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Milestones',
          table: 'milestones',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'secure_store key milestones_v1',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/milestones_provider.dart',
          uiFile: 'lib/features/progression/ui/progression_screen.dart',
          createPath: 'Yes (local)',
          readPath: 'Yes (local)',
          updatePath: 'Yes (local)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (SecureStore)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'milestones_provider.dart:70',
            'local_user_data_cleanup_service.dart:40',
            'progression_screen.dart:109',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Soul Maps',
          table: 'soul_maps',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'SharedPrefs key soul_map_profile_v1',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/soul_map_provider.dart',
          uiFile: 'lib/features/si_console/ui/si_console_screen.dart',
          createPath: 'Yes (local save)',
          readPath: 'Yes (local load)',
          updatePath: 'Yes (setProfile)',
          deletePath: 'No explicit delete path',
          restartPersistence: 'Yes (SharedPrefs)',
          loginLogoutPersistence:
              'Likely persists unless explicit clear key is added',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'soul_map_provider.dart:20,24,35,46',
            'si_console_screen.dart:297',
          ],
        ),
        CoreEntityAuditItem(
          feature: 'Memory Engine',
          table: 'memoryEngine',
          status: CoreEntityStatus.localOnly,
          localRepositoryFile: 'lib/data/repositories/memory_repository.dart',
          supabaseRepositoryFile: '-',
          providerFile: 'lib/state/providers/memories_provider.dart',
          uiFile: 'lib/features/si_console/ui/si_console_screen.dart',
          createPath: 'Yes (local)',
          readPath: 'Yes (local)',
          updatePath: 'Yes (save existing id)',
          deletePath: 'Yes (local)',
          restartPersistence: 'Yes (SharedPrefs)',
          loginLogoutPersistence: 'No (cleared on logout)',
          supabasePersistenceStatus: 'Local persistence only',
          localOnlyFallback: true,
          evidence: <String>[
            'memory_repository.dart:15,58,72,81',
            'memories_provider.dart:33,144',
            'si_console_screen.dart:3',
          ],
        ),
      ];
}
