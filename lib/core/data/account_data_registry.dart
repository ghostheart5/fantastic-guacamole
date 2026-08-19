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
