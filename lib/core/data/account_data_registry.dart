import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';

enum AccountDataBackupStatus { backedUp, localOnly, cloudReplicated, internal }

class AccountDataDomain {
  const AccountDataDomain({
    required this.id,
    required this.label,
    required this.owner,
    required this.backupStatus,
    required this.storage,
    this.notes,
  });

  final String id;
  final String label;
  final String owner;
  final AccountDataBackupStatus backupStatus;
  final String storage;
  final String? notes;

  Map<String, dynamic> toManifestJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'owner': owner,
    'backupStatus': backupStatus.name,
    'storage': storage,
    if (notes != null) 'notes': notes,
  };
}

/// One immutable cleanup inventory for either legacy unowned data or a known
/// departing account. Consumers should use this plan instead of selecting
/// individual key sets independently.
class AccountDataCleanupPlan {
  const AccountDataCleanupPlan({
    required this.hiveBoxes,
    required this.secureExactKeys,
    required this.secureKeyPrefixes,
    required this.sensitivePreferenceKeys,
    required this.preferenceExactKeys,
    required this.preferenceKeyPrefixes,
  });

  final Set<String> hiveBoxes;
  final Set<String> secureExactKeys;
  final Set<String> secureKeyPrefixes;
  final Set<String> sensitivePreferenceKeys;
  final Set<String> preferenceExactKeys;
  final Set<String> preferenceKeyPrefixes;
}

/// Single inventory for account-owned local/cloud domains.
///
/// This deliberately separates "known account data" from "currently included
/// in backup" so restore/sync code cannot silently call a partial snapshot a
/// complete account backup.
const List<AccountDataDomain> accountDataDomains = <AccountDataDomain>[
  AccountDataDomain(
    id: 'tasks',
    label: 'Tasks',
    owner: 'Smart Planner / Timeline',
    backupStatus: AccountDataBackupStatus.backedUp,
    storage: 'Hive task repository + Supabase Storage backup payload',
  ),
  AccountDataDomain(
    id: 'profile',
    label: 'Profile',
    owner: 'Profile / Progression',
    backupStatus: AccountDataBackupStatus.backedUp,
    storage: 'SecureStore profile_state_v2 with legacy Hive fallback',
  ),
  AccountDataDomain(
    id: 'settings',
    label: 'Settings',
    owner: 'Settings',
    backupStatus: AccountDataBackupStatus.backedUp,
    storage: 'SharedPreferences settings payload',
  ),
  AccountDataDomain(
    id: 'task_occurrences',
    label: 'Task occurrences',
    owner: 'Timeline / Smart Planner recurrence ledger',
    backupStatus: AccountDataBackupStatus.cloudReplicated,
    storage: 'Account-scoped Hive ledger + Supabase task_occurrences table',
  ),
  AccountDataDomain(
    id: 'goals',
    label: 'Goals',
    owner: 'Progression',
    backupStatus: AccountDataBackupStatus.localOnly,
    storage: 'Hive goals box',
  ),
  AccountDataDomain(
    id: 'habits',
    label: 'Habits',
    owner: 'Progression / Smart Planner',
    backupStatus: AccountDataBackupStatus.localOnly,
    storage: 'Hive habits box',
  ),
  AccountDataDomain(
    id: 'timeline',
    label: 'Timeline events',
    owner: 'Timeline',
    backupStatus: AccountDataBackupStatus.localOnly,
    storage: 'Sensitive preferences timeline store',
  ),
  AccountDataDomain(
    id: 'notes',
    label: 'Creator notes',
    owner: 'Creator',
    backupStatus: AccountDataBackupStatus.localOnly,
    storage: 'Shared preferences notes store',
  ),
  AccountDataDomain(
    id: 'si_state',
    label: 'SI state',
    owner: 'SI Console',
    backupStatus: AccountDataBackupStatus.localOnly,
    storage: 'SecureStore SI repository',
  ),
  AccountDataDomain(
    id: 'diagnostics',
    label: 'Diagnostics and advisor outputs',
    owner: 'Internal diagnostics',
    backupStatus: AccountDataBackupStatus.internal,
    storage: 'Local/internal diagnostic providers',
  ),
];

Map<String, dynamic> accountDataBackupManifest() {
  final List<String> included = accountDataDomains
      .where(
        (AccountDataDomain domain) =>
            domain.backupStatus == AccountDataBackupStatus.backedUp,
      )
      .map((AccountDataDomain domain) => domain.id)
      .toList(growable: false);
  final List<String> cloudReplicated = accountDataDomains
      .where(
        (AccountDataDomain domain) =>
            domain.backupStatus == AccountDataBackupStatus.cloudReplicated,
      )
      .map((AccountDataDomain domain) => domain.id)
      .toList(growable: false);
  final List<String> excluded = accountDataDomains
      .where(
        (AccountDataDomain domain) =>
            domain.backupStatus == AccountDataBackupStatus.localOnly ||
            domain.backupStatus == AccountDataBackupStatus.internal,
      )
      .map((AccountDataDomain domain) => domain.id)
      .toList(growable: false);

  return <String, dynamic>{
    'manifestVersion': 1,
    'includedDomains': included,
    'cloudReplicatedDomains': cloudReplicated,
    'excludedDomains': excluded,
    'domains': accountDataDomains
        .map((AccountDataDomain domain) => domain.toManifestJson())
        .toList(growable: false),
  };
}

/// Canonical persistence inventory for account cleanup and account-scoped keys.
///
/// Device-global preferences are listed separately so account departure cannot
/// silently reset onboarding, theme, tutorial, or the device encryption key.
abstract final class AccountDataRegistry {
  static const String accountBoundaryOwnerKey =
      'auth_boundary_account_marker_v1';
  static const String legacyNotificationSecureKey = 'notification_entries_v1';
  static const String notificationSecureKeyPrefix = 'notification_entries_v2.';

  static const Set<String> legacyAccountHiveBoxes = <String>{
    'tasks_box',
    'goals_box',
    'habits_box',
    'projects_box',
    'routines_box',
    'subtasks_box',
    'progression_box',
    'daily_plans_box',
    'offline_queue_box',
    'notifications_box',
    'timeline_box',
    'cache_box',
    'profile_box',
    'tasks',
    'auth_credentials_box',
    'auth_session_box',
    'identity_box',
  };

  static const Set<String> accountSecureExactKeys = <String>{
    'identity_id',
    'auth_credentials_box',
    'auth_session_box',
    'identity_profile_v1',
    'calendar_entries_v1',
    'chrono_log_entries_v2',
    'learning_state_v1',
    'ai_learning',
    'workspace_entity_v1',
    'workspace_creator_v1',
    'workspace_temporal_v1',
    'workspace_si_v1',
    'milestones_v1',
    'profile_entity_v1',
    'profile_state_v2',
    legacyNotificationSecureKey,
    'si_engine_state_v1',
    'neural_dump',
    'paywall_subscription_state_v1',
    'entitlement_owner_user_id_v1',
    'bridge.firebase_messaging_token',
    'timeline_payload_v1',
    'task_entries_v2',
    'settings_v1_neon_recall',
    'settings_v1_si_module',
    'settings_v1_notifications',
    'settings_v1_analytics_sharing',
    'settings_v1_data_sync',
    'settings_v1_compact_mode',
    'settings_v1_text_scale',
    'settings_v1_si_tuning',
    'workspace_sync_cache_v1',
    'ai_runtime_cache_v1',
    'si_engine_state_legacy',
    'legacy_workspace_payload',
    'deprecated_session_shadow',
    accountBoundaryOwnerKey,
  };

  static const Set<String> legacySensitivePreferenceKeys = <String>{
    'goals_v1',
    'goals_v2',
    'memories_v1',
    'timeline_events_v1',
  };

  static const Set<String> accountPreferenceExactKeys = <String>{
    'insights_v1',
    'signals_v1',
    'behavior_state_v1',
    'self_opt_config_v1',
    'self_opt_last_adjust',
    'soul_map_profile_v1',
    'personalization_profile_v1',
    'observed_planning_patterns_v1',
    'profile_values',
    'user_preferences_json',
    'primary_goal_type',
    'last_opened_tab',
    'rec_last_route',
    'rec_active_task',
    'rec_draft_title',
    'last_route',
    'active_task_id',
    'draft_task_title',
    'ai_credit_wallet',
    'cloud_sync_enabled_v1',
    'reflection_reminder_enabled',
    'reflection_reminder_time',
    'goal_reminders_enabled',
    'habit_reminders_enabled',
    'daily_planning_reminder_enabled',
    'daily_planning_reminder_time',
    'paywall_auto_restore_prompted_v1',
    'paywall_subscription_state_v1',
    'settings',
    'lma_date',
    'lma_tasks_created',
    'lma_tasks_completed',
    'lma_momentum_peak',
    'global_metrics_cache',
    'global_metrics_cache_ts',
    'local_test_cloud_backup',
    'local_test_cloud_tasks',
    'debug_last_screen',
    'pending_deep_link_v1',
    'recent_permission_prompt_cache',
    'legacy_onboarding_step',
    'legacy_route_override',
    'deprecated_theme_seed',
    'extended_domain.'
        'coa'
        'ch_messages',
    'extended_domain.planner_messages',
    'extended_domain.si_queries',
    'extended_domain.user_intents',
    'extended_domain.reflection_entries',
    'extended_domain.journal_entries',
    'extended_domain.analytics_metrics',
    'extended_domain.app_notifications',
    'extended_domain.rewards',
    'extended_domain.themes',
    'extended_domain.settings',
    'extended_domain.sync_states',
    'extended_domain.offline_states',
    'extended_domain.app_errors',
    'extended_domain.recovery_states',
    'extended_domain.subscription_plans',
    'extended_domain.privacy_policies',
    'extended_domain.health_checks',
  };

  static const Set<String> deviceGlobalPreferenceKeys = <String>{
    'app_theme_entity_v1',
    'settings_entity_v1',
    'onboarding_complete',
    'onboarding_content_version',
    'tutorial_progress_v1',
  };

  static String accountDigest(String accountId) {
    final String normalized = accountId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'Must not be empty.');
    }
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String accountNamespace(String accountId) {
    return AccountStorageScope.authenticated(accountId.trim()).v2Namespace!;
  }

  static String notificationSecureKeyFor(String accountId) {
    return '$notificationSecureKeyPrefix${accountDigest(accountId)}';
  }

  static String notificationMutationKeyFor(String accountId) {
    return 'notification-account:${accountDigest(accountId)}';
  }

  static Set<String> hiveBoxesForAccount(String accountId) {
    final String namespace = accountNamespace(accountId);
    return <String>{
      ...legacyAccountHiveBoxes,
      'task_occurrences_v2.$namespace',
    };
  }

  static Set<String> secureExactKeysForAccount(String accountId) {
    final String namespace = accountNamespace(accountId);
    return <String>{
      ...accountSecureExactKeys,
      notificationSecureKeyFor(accountId),
      'creator_latest_receipt_v1:$namespace',
      'creator_handshake_ledger_v1:$namespace',
    };
  }

  static Set<String> secureKeyPrefixesForAccount(String accountId) {
    final String namespace = accountNamespace(accountId);
    return <String>{'si_engine_state_v2.$namespace.'};
  }

  static Set<String> sensitivePreferenceKeysForAccount(String accountId) {
    final String namespace = accountNamespace(accountId);
    return <String>{
      ...legacySensitivePreferenceKeys,
      'governed_memories_v2.$namespace',
    };
  }

  static Set<String> preferenceExactKeysForAccount(String accountId) {
    final String namespace = accountNamespace(accountId);
    final String namespaceDigest = sha256
        .convert(utf8.encode(namespace))
        .toString();
    return <String>{
      ...accountPreferenceExactKeys,
      'chronospark.decision_outcomes.v1.$namespace',
      'chronospark.trajectory.forecast_ledger.v1.$namespace',
      'chronospark.operating.history.v1.$namespace',
      'chronospark.operating.ack.v1.$namespace',
      'onboarding_profile_complete_v1.$namespace',
      'assistant_beta_opt_in_v1.$namespaceDigest',
    };
  }

  static Set<String> preferenceKeyPrefixesForAccount(String accountId) {
    final String namespace = accountNamespace(accountId);
    return <String>{
      'adaptive_guidance_v3.$namespace.',
      'chronospark.trajectory.forecast_ledger.v1.$namespace.corrupt.',
      'chronospark.operating.history.v1.$namespace.corrupt.',
    };
  }

  static AccountDataCleanupPlan cleanupPlanFor(String? accountId) {
    final String normalizedAccountId = accountId?.trim() ?? '';
    if (normalizedAccountId.isEmpty) {
      return const AccountDataCleanupPlan(
        hiveBoxes: legacyAccountHiveBoxes,
        secureExactKeys: accountSecureExactKeys,
        secureKeyPrefixes: <String>{},
        sensitivePreferenceKeys: legacySensitivePreferenceKeys,
        preferenceExactKeys: accountPreferenceExactKeys,
        preferenceKeyPrefixes: <String>{},
      );
    }

    return AccountDataCleanupPlan(
      hiveBoxes: hiveBoxesForAccount(normalizedAccountId),
      secureExactKeys: secureExactKeysForAccount(normalizedAccountId),
      secureKeyPrefixes: secureKeyPrefixesForAccount(normalizedAccountId),
      sensitivePreferenceKeys: sensitivePreferenceKeysForAccount(
        normalizedAccountId,
      ),
      preferenceExactKeys: preferenceExactKeysForAccount(normalizedAccountId),
      preferenceKeyPrefixes: preferenceKeyPrefixesForAccount(
        normalizedAccountId,
      ),
    );
  }
}
