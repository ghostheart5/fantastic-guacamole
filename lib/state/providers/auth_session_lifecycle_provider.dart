import 'dart:convert';
import 'dart:math';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart'
    show
        firebaseSupabaseBridgeRepositoryProvider,
        completionEventRepositoryProvider,
        goalRepositoryProvider,
        habitRepositoryProvider,
        planRepositoryProvider,
        settingsRepositoryProvider,
        syncMutationDispatcherProvider,
        taskRepositoryProvider,
        timelineRepositoryProvider;
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/repositories/firebase_supabase_bridge_repository.dart';
import 'package:fantastic_guacamole/data/services/auth_service.dart';
import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/features/auth/application/auth_providers.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_session_state_provider.dart';
import 'package:fantastic_guacamole/features/monetization/providers/monetization_feature_providers.dart'
    show refreshMonetizationRemoteState;
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart' as ai;
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_connection_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_security_provider.dart';
import 'package:fantastic_guacamole/state/providers/app_startup_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/behavior_provider.dart';
import 'package:fantastic_guacamole/state/providers/chronospark_passport_provider.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_actions_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_account_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_bootstrap_provider.dart';
import 'package:fantastic_guacamole/state/providers/identity_provider.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart'
    as legacy_paywall;
import 'package:fantastic_guacamole/state/providers/profile_values_provider.dart';
import 'package:fantastic_guacamole/state/providers/progression_provider.dart';
import 'package:fantastic_guacamole/state/providers/projects_provider.dart';
import 'package:fantastic_guacamole/state/providers/routines_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/soul_map_provider.dart';
import 'package:fantastic_guacamole/state/providers/subtasks_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_backend_provider.dart';
import 'package:fantastic_guacamole/state/providers/supabase_sync_queue_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_misc_usecase_providers.dart'
    show viewTimelineUsecaseProvider;
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_command_handoff_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart'
    show
        firebaseSupabaseBridgeProvider,
        reminderOrchestratorServiceProvider,
        siEngineDependenciesProvider,
        siEngineServiceProvider;
import 'package:fantastic_guacamole/state/providers/session_recovery_provider.dart';
import 'package:fantastic_guacamole/state/services/extended_domain_service.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:fantastic_guacamole/tutorial/mission/mission_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _authTransitionCleanupProvider = Provider<LocalUserDataCleanupService>((
  Ref ref,
) {
  return LocalUserDataCleanupService(
    preferences: ref.watch(sharedPrefsStoreProvider),
    hive: ref.watch(hiveStoreProvider),
    secureStore: ref.watch(secureStoreProvider),
  );
});

final _sessionOwnershipStoreProvider = Provider<_SessionOwnershipStore>((
  Ref ref,
) {
  return _SessionOwnershipStore(
    secureStore: ref.watch(secureStoreProvider),
    hive: ref.watch(hiveStoreProvider),
  );
});

class _SessionOwnerRecord {
  const _SessionOwnerRecord._({
    required this.raw,
    this.userId,
    this.signedOutNonce,
    this.unverifiedNonce,
  });

  factory _SessionOwnerRecord.parse(String? value) {
    if (value == null) {
      return const _SessionOwnerRecord._(raw: null);
    }
    final String normalized = value.trim();
    if (normalized.startsWith(_SessionOwnershipStore.userPrefix)) {
      final String userId = normalized
          .substring(_SessionOwnershipStore.userPrefix.length)
          .trim();
      if (userId.isNotEmpty) {
        return _SessionOwnerRecord._(raw: normalized, userId: userId);
      }
    }
    if (normalized.startsWith(_SessionOwnershipStore.signedOutPrefix)) {
      final String nonce = normalized
          .substring(_SessionOwnershipStore.signedOutPrefix.length)
          .trim();
      if (nonce.isNotEmpty) {
        return _SessionOwnerRecord._(raw: normalized, signedOutNonce: nonce);
      }
    }
    if (normalized.startsWith(_SessionOwnershipStore.unverifiedPrefix)) {
      final String nonce = normalized
          .substring(_SessionOwnershipStore.unverifiedPrefix.length)
          .trim();
      if (nonce.isNotEmpty) {
        return _SessionOwnerRecord._(raw: normalized, unverifiedNonce: nonce);
      }
    }
    return _SessionOwnerRecord._(raw: normalized);
  }

  final String? raw;
  final String? userId;
  final String? signedOutNonce;
  final String? unverifiedNonce;

  bool get isMissing => raw == null;
  bool get isSignedOut => signedOutNonce != null;
  bool get isUnverified => unverifiedNonce != null;

  bool matches(String? expectedUserId) {
    if (expectedUserId == null) {
      return isSignedOut;
    }
    return userId == expectedUserId;
  }
}

class _LegacyOwnershipAssessment {
  const _LegacyOwnershipAssessment({
    this.blockingIssue,
    this.requiresAuthenticatedOwnerConfirmation = false,
    this.canDiscardAfterConfirmation = false,
    this.authenticatedOwnerId,
  });

  final String? blockingIssue;
  final bool requiresAuthenticatedOwnerConfirmation;
  final bool canDiscardAfterConfirmation;
  final String? authenticatedOwnerId;
  bool get canClaim => blockingIssue == null;
}

class _SessionOwnershipStore {
  const _SessionOwnershipStore({
    required this._secureStore,
    required this._hive,
  });

  static const String ownerKey = 'chronospark.local_session_owner.v1';
  static const String userPrefix = 'user:';
  static const String signedOutPrefix = 'signed_out:';
  static const String unverifiedPrefix = 'legacy_unverified:';

  final SecureStore _secureStore;
  final HiveStore _hive;

  Future<_SessionOwnerRecord> readOwner() async {
    return _SessionOwnerRecord.parse(await _secureStore.readString(ownerKey));
  }

  Future<void> claimUser(String userId) {
    return _secureStore.writeString(ownerKey, '$userPrefix$userId');
  }

  Future<void> claimSignedOut() {
    return _secureStore.writeString(ownerKey, '$signedOutPrefix${_newNonce()}');
  }

  Future<void> claimUnverifiedSignedOut() {
    return _secureStore.writeString(
      ownerKey,
      '$unverifiedPrefix${_newNonce()}',
    );
  }

  Future<_LegacyOwnershipAssessment> assessLegacyOwnership(
    String? expectedUserId, {
    required bool allowRestoredSessionClaim,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? encodedIdentity = preferences.getString(
      'chronospark.identity',
    );
    final Map<String, String> secureValues = await _secureStore.readAll();
    final String? identityOwnerId = _legacyIdentityAuthenticatedUserId(
      encodedIdentity,
    );
    final String? cachedOwnerId = _legacyCachedSessionUserId(
      secureValues['auth.cached_session'],
    );
    final bool conflictingOwnerEvidence =
        identityOwnerId != null &&
        cachedOwnerId != null &&
        identityOwnerId != cachedOwnerId;
    if (expectedUserId == null && conflictingOwnerEvidence) {
      return const _LegacyOwnershipAssessment(
        requiresAuthenticatedOwnerConfirmation: true,
      );
    }
    final String? discoveredOwnerId = identityOwnerId ?? cachedOwnerId;
    final String? rawExpectedScope = expectedUserId ?? discoveredOwnerId;
    final String? expectedScope = rawExpectedScope == null
        ? null
        : _safeStorageScope(rawExpectedScope);

    final String? identityIssue = _legacyIdentityIssue(
      encodedIdentity,
      expectedUserId,
    );
    if (identityIssue != null) {
      return expectedUserId == null
          ? const _LegacyOwnershipAssessment(
              requiresAuthenticatedOwnerConfirmation: true,
            )
          : _LegacyOwnershipAssessment(blockingIssue: identityIssue);
    }

    final String? scopedPrefsIssue = _foreignScopedPreferencesIssue(
      preferences.getKeys(),
      expectedUserId,
      expectedScope,
    );
    if (scopedPrefsIssue != null) {
      return expectedUserId == null
          ? const _LegacyOwnershipAssessment(
              requiresAuthenticatedOwnerConfirmation: true,
            )
          : _LegacyOwnershipAssessment(blockingIssue: scopedPrefsIssue);
    }

    final String? cachedSessionIssue = _legacyCachedSessionIssue(
      secureValues['auth.cached_session'],
      expectedUserId,
    );
    if (cachedSessionIssue != null) {
      return expectedUserId == null
          ? const _LegacyOwnershipAssessment(
              requiresAuthenticatedOwnerConfirmation: true,
            )
          : _LegacyOwnershipAssessment(blockingIssue: cachedSessionIssue);
    }
    final String? scopedSecureIssue = _foreignScopedSecureIssue(
      secureValues.keys,
      expectedScope,
    );
    if (scopedSecureIssue != null) {
      return expectedUserId == null
          ? const _LegacyOwnershipAssessment(
              requiresAuthenticatedOwnerConfirmation: true,
            )
          : _LegacyOwnershipAssessment(blockingIssue: scopedSecureIssue);
    }

    final bool hasAffirmativeOwnerEvidence =
        _legacyIdentityAffirmsOwnership(encodedIdentity, expectedUserId) ||
        _legacyCachedSessionAffirmsOwnership(
          secureValues['auth.cached_session'],
          expectedUserId,
        );
    if (!hasAffirmativeOwnerEvidence &&
        await _hasPrivateLegacyData(preferences, secureValues)) {
      if (expectedUserId != null) {
        if (allowRestoredSessionClaim) {
          return _LegacyOwnershipAssessment(
            authenticatedOwnerId: expectedUserId,
          );
        }
        return const _LegacyOwnershipAssessment(
          blockingIssue:
              'ChronoSpark found private legacy data without a verifiable account owner. The data was preserved and the authenticated account was blocked.',
          canDiscardAfterConfirmation: true,
        );
      }
      return const _LegacyOwnershipAssessment(
        requiresAuthenticatedOwnerConfirmation: true,
      );
    }

    return _LegacyOwnershipAssessment(
      authenticatedOwnerId: expectedUserId == null ? discoveredOwnerId : null,
    );
  }

  Future<bool> _hasPrivateLegacyData(
    SharedPreferences preferences,
    Map<String, String> secureValues,
  ) async {
    const Set<String> privatePreferenceKeys = <String>{
      'behavior_state_v1',
      'profile_values',
      'soul_map_profile_v1',
      'si_decision_snapshot_v1',
    };
    if (preferences.getKeys().any(
      (String key) =>
          privatePreferenceKeys.contains(key) ||
          key.startsWith('extended_domain.'),
    )) {
      return true;
    }

    const Set<String> privateSecureKeys = <String>{
      'profile_state_v2',
      'ai_learning',
      'neural_dump',
      'workspace_creator_v1',
      'workspace_temporal_v1',
      'workspace_si_v1',
      'si_engine_workspace_v1',
      'si_state_entity_v1',
      'task_entries_v2',
      'profile_entity_v1',
      'identity_profile_v1',
      'workspace_entity_v1',
      'sessions_entity_v1',
      'milestones_v1',
      'notification_entries_v1',
      'chrono_log_entries_v2',
      'calendar_entries_v1',
      'paywall_subscription_state_v1',
    };
    if (secureValues.keys.any(privateSecureKeys.contains)) {
      return true;
    }

    const Set<String> privateHiveBoxes = <String>{
      HiveBoxes.tasks,
      HiveBoxes.goals,
      HiveBoxes.habits,
      HiveBoxes.projects,
      HiveBoxes.routines,
      HiveBoxes.subtasks,
      HiveBoxes.progression,
      HiveBoxes.dailyPlans,
      HiveBoxes.offlineQueue,
      HiveBoxes.notifications,
      HiveBoxes.timeline,
      'profile_box',
    };
    await _hive.init();
    for (final String name in privateHiveBoxes) {
      final bool wasOpen = _hive.isBoxOpen(name);
      final box = await _hive.openBox<dynamic>(name);
      final bool containsData = box.isNotEmpty;
      if (!wasOpen) {
        await _hive.closeBox(name);
      }
      if (containsData) {
        return true;
      }
    }
    return false;
  }

  Future<void> migrateTrustedLegacyUserData(String userId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await ExtendedDomainService.migrateLegacyStorage(
      prefs: preferences,
      storageScope: userId,
    );
    await ProfileController.migrateLegacyStorage(
      secureStore: _secureStore,
      hiveStore: _hive,
      userId: userId,
    );
    await LearningController.migrateLegacyStorage(
      store: _secureStore,
      userId: userId,
    );
  }

  static String? _legacyIdentityIssue(String? encoded, String? expectedUserId) {
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('identity payload is not an object');
      }
      final String id = decoded['id']?.toString().trim() ?? '';
      final String syncStatus = decoded['syncStatus']?.toString().trim() ?? '';
      final bool accountBacked =
          id.isNotEmpty &&
          !id.startsWith('local-') &&
          syncStatus != 'localOnly' &&
          syncStatus != 'signedOut';
      if (accountBacked && id != expectedUserId) {
        return 'ChronoSpark preserved legacy data owned by a different '
            'account than the restored authentication session.';
      }
      return null;
    } on Object {
      return 'ChronoSpark preserved unreadable legacy identity ownership '
          'metadata instead of guessing which account owns it.';
    }
  }

  static String? _legacyCachedSessionIssue(
    String? encoded,
    String? expectedUserId,
  ) {
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? rawUser = decoded['user'];
      if (rawUser is! Map) {
        return null;
      }
      final String cachedUserId = rawUser['id']?.toString().trim() ?? '';
      if (cachedUserId.isNotEmpty && cachedUserId != expectedUserId) {
        return 'ChronoSpark preserved a legacy authenticated session owned '
            'by a different account than the current authentication state.';
      }
    } on Object {
      return null;
    }
    return null;
  }

  static bool _legacyIdentityAffirmsOwnership(
    String? encoded,
    String? expectedUserId,
  ) {
    if (encoded == null || encoded.trim().isEmpty) {
      return false;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final String id = decoded['id']?.toString().trim() ?? '';
      final String syncStatus = decoded['syncStatus']?.toString().trim() ?? '';
      final bool localOwner =
          id.startsWith('local-') ||
          syncStatus == 'localOnly' ||
          syncStatus == 'signedOut';
      return localOwner || (id.isNotEmpty && id == expectedUserId);
    } on Object {
      return false;
    }
  }

  static bool _legacyCachedSessionAffirmsOwnership(
    String? encoded,
    String? expectedUserId,
  ) {
    if (encoded == null || encoded.trim().isEmpty || expectedUserId == null) {
      return false;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      final Object? rawUser = decoded['user'];
      return rawUser is Map &&
          rawUser['id']?.toString().trim() == expectedUserId;
    } on Object {
      return false;
    }
  }

  static String? _legacyIdentityAuthenticatedUserId(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final String id = decoded['id']?.toString().trim() ?? '';
      final String syncStatus = decoded['syncStatus']?.toString().trim() ?? '';
      final bool accountBacked =
          id.isNotEmpty &&
          !id.startsWith('local-') &&
          syncStatus != 'localOnly' &&
          syncStatus != 'signedOut';
      return accountBacked ? id : null;
    } on Object {
      return null;
    }
  }

  static String? _legacyCachedSessionUserId(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? rawUser = decoded['user'];
      if (rawUser is! Map) {
        return null;
      }
      final String id = rawUser['id']?.toString().trim() ?? '';
      return id.isEmpty ? null : id;
    } on Object {
      return null;
    }
  }

  static String? _foreignScopedPreferencesIssue(
    Set<String> keys,
    String? expectedUserId,
    String? expectedScope,
  ) {
    final Set<String> allowed = <String>{
      onboardingCompleteStorageKey,
      onboardingContentVersionStorageKey,
      onboardingStepStorageKey,
      onboardingCanonicalStateStorageKey,
      creatorFirstItemCreatedStorageKey,
      timelineFirstActionCompletedStorageKey,
      'mission_zero_overlay_dismissed',
      'mission_zero_overlay_dismissed.signed_out',
      if (expectedUserId != null) ...<String>{
        onboardingCompleteStorageKeyForUser(expectedUserId),
        onboardingContentVersionStorageKeyForUser(expectedUserId),
        onboardingStepStorageKeyForUser(expectedUserId),
        onboardingCanonicalStateStorageKeyForUser(expectedUserId),
        creatorFirstItemCreatedStorageKeyForUser(expectedUserId),
        timelineFirstActionCompletedStorageKeyForUser(expectedUserId),
      },
      if (expectedScope != null)
        'mission_zero_overlay_dismissed.$expectedScope',
    };
    const List<String> scopedPrefixes = <String>[
      '${onboardingCompleteStorageKey}_',
      '${onboardingContentVersionStorageKey}_',
      '${onboardingStepStorageKey}_',
      '${onboardingCanonicalStateStorageKey}_',
      '${creatorFirstItemCreatedStorageKey}_',
      '${timelineFirstActionCompletedStorageKey}_',
      'mission_zero_overlay_dismissed.',
    ];
    for (final String key in keys) {
      if (allowed.contains(key)) {
        continue;
      }
      if (scopedPrefixes.any(key.startsWith)) {
        return 'ChronoSpark preserved legacy preferences scoped to another '
            'account instead of assigning them to the restored session.';
      }
    }
    return null;
  }

  static String? _foreignScopedSecureIssue(
    Iterable<String> keys,
    String? expectedScope,
  ) {
    for (final String key in keys) {
      for (final String prefix in const <String>[
        'profile_state_v2.',
        'ai_learning.',
      ]) {
        if (!key.startsWith(prefix)) {
          continue;
        }
        final String scope = key.substring(prefix.length);
        if (scope == 'signed_out' || scope == expectedScope) {
          continue;
        }
        return 'ChronoSpark preserved secure legacy state scoped to another '
            'account instead of assigning it to the restored session.';
      }
    }
    return null;
  }

  static String _newNonce() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class _SignedOutStateHandoff {
  const _SignedOutStateHandoff({
    required this.ownerNonce,
    required this.onboardingComplete,
    required this.onboardingVersion,
    required this.onboardingStep,
    required this.canonicalState,
    required this.creatorFirstItemCreated,
    required this.timelineFirstActionCompleted,
    required this.missionOverlayDismissed,
    required this.signedOutProfileState,
  });

  static const String _missionOverlayKey = 'mission_zero_overlay_dismissed';
  static const String _signedOutMissionOverlayKey =
      'mission_zero_overlay_dismissed.signed_out';

  final String ownerNonce;
  final bool onboardingComplete;
  final int onboardingVersion;
  final int onboardingStep;
  final String? canonicalState;
  final bool? creatorFirstItemCreated;
  final bool? timelineFirstActionCompleted;
  final bool? missionOverlayDismissed;
  final String? signedOutProfileState;

  bool get hasValues =>
      onboardingComplete ||
      missionOverlayDismissed != null ||
      signedOutProfileState != null;

  static Future<_SignedOutStateHandoff> capture(
    String ownerNonce,
    SecureStore secureStore,
  ) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool complete =
        _coerceStoredBool(preferences.get(onboardingCompleteStorageKey)) ??
        false;
    return _SignedOutStateHandoff(
      ownerNonce: ownerNonce,
      onboardingComplete: complete,
      onboardingVersion:
          _coerceStoredInt(
            preferences.get(onboardingContentVersionStorageKey),
          ) ??
          onboardingContentVersion,
      onboardingStep:
          _coerceStoredInt(preferences.get(onboardingStepStorageKey)) ?? 0,
      canonicalState: preferences.getString(onboardingCanonicalStateStorageKey),
      creatorFirstItemCreated: _coerceStoredBool(
        preferences.get(creatorFirstItemCreatedStorageKey),
      ),
      timelineFirstActionCompleted: _coerceStoredBool(
        preferences.get(timelineFirstActionCompletedStorageKey),
      ),
      missionOverlayDismissed:
          _coerceStoredBool(preferences.get(_missionOverlayKey)) ??
          _coerceStoredBool(preferences.get(_signedOutMissionOverlayKey)),
      signedOutProfileState: await secureStore.readString(
        ProfileController.secureStorageKeyForUser(null),
      ),
    );
  }

  Future<void> applyTo(String userId, SecureStore secureStore) async {
    if (ownerNonce.trim().isEmpty || !hasValues) {
      return;
    }
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (onboardingComplete) {
      await SharedPrefsService.saveBoolWithPrefs(
        preferences,
        onboardingCompleteStorageKeyForUser(userId),
        true,
      );
      await SharedPrefsService.saveIntWithPrefs(
        preferences,
        onboardingContentVersionStorageKeyForUser(userId),
        onboardingVersion,
      );
      await SharedPrefsService.saveIntWithPrefs(
        preferences,
        onboardingStepStorageKeyForUser(userId),
        onboardingStep,
      );
      await SharedPrefsService.saveStringWithPrefs(
        preferences,
        onboardingCanonicalStateStorageKeyForUser(userId),
        canonicalState ??
            jsonEncode(
              buildOnboardingCanonicalStatePayload(
                complete: true,
                version: onboardingVersion,
              ),
            ),
      );
      await SharedPrefsService.saveBoolWithPrefs(
        preferences,
        creatorFirstItemCreatedStorageKeyForUser(userId),
        creatorFirstItemCreated ?? false,
      );
      await SharedPrefsService.saveBoolWithPrefs(
        preferences,
        timelineFirstActionCompletedStorageKeyForUser(userId),
        timelineFirstActionCompleted ?? false,
      );
    }
    final bool? dismissed = missionOverlayDismissed;
    if (dismissed != null) {
      await SharedPrefsService.saveBoolWithPrefs(
        preferences,
        '$_missionOverlayKey.${_safeStorageScope(userId)}',
        dismissed,
      );
    }
    final String? profileState = signedOutProfileState;
    if (profileState != null && profileState.trim().isNotEmpty) {
      final String targetKey = ProfileController.secureStorageKeyForUser(
        userId,
      );
      final String? existing = await secureStore.readString(targetKey);
      if (existing == null || existing.trim().isEmpty) {
        await secureStore.writeString(targetKey, profileState);
      }
      await secureStore.delete(ProfileController.secureStorageKeyForUser(null));
    }
    for (final String key in <String>{
      onboardingCompleteStorageKey,
      onboardingContentVersionStorageKey,
      onboardingStepStorageKey,
      onboardingCanonicalStateStorageKey,
      creatorFirstItemCreatedStorageKey,
      timelineFirstActionCompletedStorageKey,
      _missionOverlayKey,
      _signedOutMissionOverlayKey,
    }) {
      await SharedPrefsService.deleteWithPrefs(preferences, key);
    }
  }
}

final authSessionLifecycleProvider = Provider<AuthSessionLifecycleCoordinator>((
  Ref ref,
) {
  return AuthSessionLifecycleCoordinator(ref);
});

class AuthSessionLifecycleCoordinator {
  AuthSessionLifecycleCoordinator(this._ref);

  final Ref _ref;
  bool _initialized = false;
  String? _currentUserId;
  Future<void> _transitionTail = Future<void>.value();

  Future<int> initialize(User? user) {
    return _enqueueTransition(() => _transitionSerial(user, isStartup: true));
  }

  Future<int> synchronizeCurrentUser() {
    return synchronize(_ref.read(authServiceProvider).currentUser);
  }

  void refreshRemoteSessionState() {
    final AuthSessionBoundary boundary = _ref.read(authSessionBoundaryProvider);
    if (boundary.isTransitioning || boundary.blockingIssue != null) {
      return;
    }
    refreshMonetizationRemoteState(_ref);
  }

  Future<int> synchronize(User? user) {
    return _enqueueTransition(() => _transitionSerial(user, isStartup: false));
  }

  Future<int> recoverMismatchedAuthenticatedSession() {
    return _enqueueTransition(_recoverMismatchedAuthenticatedSessionSerial);
  }

  Future<int> discardPreservedLegacyDataForCurrentSession() {
    return _enqueueTransition(_discardPreservedLegacyDataSerial);
  }

  Future<void> waitUntilIdle() => _transitionTail;

  Future<int> _enqueueTransition(Future<int> Function() action) {
    final Future<int> transition = _transitionTail.then((_) => action());
    _transitionTail = transition.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        Logger.errorCategory(
          'Auth Session',
          'Serialized authentication transition failed.',
          error,
          stackTrace,
        );
      },
    );
    return transition;
  }

  Future<void> runWhenCurrent({
    required int generation,
    required String? userId,
    required Future<void> Function() action,
  }) {
    final Future<void> operation = _transitionTail.then((_) async {
      if (!isCurrent(generation, userId)) {
        return;
      }
      await action();
    });
    _transitionTail = operation.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      Logger.errorCategory(
        'Auth Session',
        'Post-transition session work failed.',
        error,
        stackTrace,
      );
    });
    return operation;
  }

  Future<int> _transitionSerial(User? user, {required bool isStartup}) async {
    final AuthSessionBoundary existingBoundary = _ref.read(
      authSessionBoundaryProvider,
    );
    if (existingBoundary.blockingIssue != null) {
      return existingBoundary.generation;
    }

    final String? nextUserId = _normalizedUserId(user);
    if (_initialized && _currentUserId == nextUserId) {
      _setIdentity(user);
      return _ref.read(authSessionBoundaryProvider).generation;
    }

    final String? previousUserId = _currentUserId;
    final SessionRecoveryService previousSessionRecovery = _ref.read(
      sessionRecoveryProvider,
    );
    final int generation = _ref
        .read(authSessionBoundaryProvider.notifier)
        .begin(userId: nextUserId, isTransitioning: true);

    try {
      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      await _cancelAndDrainIdentityOwnedWork(
        sessionRecovery: previousSessionRecovery,
      );
      if (!_matchesBoundary(generation, nextUserId)) {
        return generation;
      }
      _invalidateIdentityOwnedState();
      _setIdentity(null);

      final authService = _ref.read(authServiceProvider);
      final bool confirmedAccountDeletion =
          previousUserId != null &&
          nextUserId == null &&
          authService is AuthService &&
          authService.consumeConfirmedAccountDeletion(previousUserId);
      final LocalUserDataCleanupService cleanup = _ref.read(
        _authTransitionCleanupProvider,
      );
      if (confirmedAccountDeletion) {
        // The backend deletion path may have performed an initial wipe before
        // the auth event. Repeat it after every identity-owned writer drained
        // so no late mutation can recreate deleted-account data.
        await cleanup.clear(userId: previousUserId);
      } else if (previousUserId != null && previousUserId != nextUserId) {
        // Sign-out cleanup can race reminder/token work started before the auth
        // event. Re-run device-external cleanup after those queues drain.
        await cleanup.prepareForSignOut();
      }

      final _SessionOwnershipStore ownershipStore = _ref.read(
        _sessionOwnershipStoreProvider,
      );
      final _SessionOwnerRecord owner = await ownershipStore.readOwner();
      bool trustedLegacyMigration = false;
      bool retainAuthenticatedOwnerWhileSignedOut = false;
      bool claimUnverifiedSignedOut = false;
      String? legacyAuthenticatedOwnerId;

      if (owner.isMissing) {
        if (confirmedAccountDeletion) {
          trustedLegacyMigration = true;
        } else if (previousUserId != null) {
          _ref
              .read(authSessionBoundaryProvider.notifier)
              .block(
                generation,
                issue:
                    'ChronoSpark preserved local-first data because its account '
                    'owner marker disappeared during sign-out. Clear local data '
                    'only through the explicit account-deletion flow.',
              );
          return generation;
        }
        final _LegacyOwnershipAssessment assessment = await ownershipStore
            .assessLegacyOwnership(
              nextUserId,
              allowRestoredSessionClaim:
                  isStartup && previousUserId == null && nextUserId != null,
            );
        if (!assessment.canClaim) {
          if (assessment.canDiscardAfterConfirmation) {
            await ownershipStore.claimUnverifiedSignedOut();
          }
          _ref
              .read(authSessionBoundaryProvider.notifier)
              .block(
                generation,
                canRecoverBySigningOut: nextUserId != null,
                canDiscardPreservedLegacyData:
                    assessment.canDiscardAfterConfirmation,
                issue: assessment.blockingIssue,
              );
          return generation;
        }
        claimUnverifiedSignedOut =
            assessment.requiresAuthenticatedOwnerConfirmation;
        legacyAuthenticatedOwnerId = assessment.authenticatedOwnerId;
        trustedLegacyMigration = true;
      } else if (owner.userId == null &&
          owner.signedOutNonce == null &&
          owner.unverifiedNonce == null) {
        _ref
            .read(authSessionBoundaryProvider.notifier)
            .block(
              generation,
              issue:
                  'ChronoSpark preserved invalid local account-ownership metadata '
                  'instead of guessing which account owns the data.',
            );
        return generation;
      } else if (owner.isUnverified) {
        if (nextUserId != null) {
          _ref
              .read(authSessionBoundaryProvider.notifier)
              .block(
                generation,
                canRecoverBySigningOut: true,
                canDiscardPreservedLegacyData: true,
                issue:
                    'ChronoSpark found private legacy data without a verifiable account owner. The data was preserved and the authenticated account was blocked.',
              );
          return generation;
        }
      } else if (owner.userId != null) {
        if (nextUserId == null) {
          retainAuthenticatedOwnerWhileSignedOut = true;
        } else if (owner.userId != nextUserId ||
            (previousUserId != null && previousUserId != nextUserId)) {
          _ref
              .read(authSessionBoundaryProvider.notifier)
              .block(
                generation,
                canRecoverBySigningOut: true,
                issue:
                    'This device contains local-first data owned by another '
                    'ChronoSpark account. The data was preserved and the new '
                    'account was blocked. Sign back into the owning account; '
                    'account switching requires a future explicit export-and-clear flow.',
              );
          return generation;
        }
      }

      _SignedOutStateHandoff? signedOutHandoff;
      final String? handoffNonce =
          owner.signedOutNonce ??
          (trustedLegacyMigration ? 'trusted-legacy-owner-migration' : null);
      if (previousUserId == null &&
          nextUserId != null &&
          handoffNonce != null) {
        final _SignedOutStateHandoff captured =
            await _SignedOutStateHandoff.capture(
              handoffNonce,
              _ref.read(secureStoreProvider),
            );
        if (captured.hasValues) {
          signedOutHandoff = captured;
        }
      }

      if (!_matchesBoundary(generation, nextUserId)) {
        return generation;
      }

      if ((trustedLegacyMigration || owner.isSignedOut) && nextUserId != null) {
        await ownershipStore.migrateTrustedLegacyUserData(nextUserId);
      }

      if (nextUserId == null) {
        if (!retainAuthenticatedOwnerWhileSignedOut &&
            (owner.isMissing || confirmedAccountDeletion)) {
          if (legacyAuthenticatedOwnerId != null) {
            await ownershipStore.claimUser(legacyAuthenticatedOwnerId);
          } else if (claimUnverifiedSignedOut) {
            await ownershipStore.claimUnverifiedSignedOut();
          } else {
            await ownershipStore.claimSignedOut();
          }
        }
      } else {
        await ownershipStore.claimUser(nextUserId);
        if (!_matchesBoundary(generation, nextUserId)) {
          return generation;
        }
        await signedOutHandoff?.applyTo(
          nextUserId,
          _ref.read(secureStoreProvider),
        );
      }

      if (!_matchesBoundary(generation, nextUserId)) {
        return generation;
      }

      _currentUserId = nextUserId;
      _initialized = true;
      _setIdentity(user);

      if (nextUserId != null) {
        final authService = _ref.read(authServiceProvider);
        if (authService is AuthService) {
          await authService.awaitCurrentUserProfileHydration();
        }
      }
      if (!_matchesBoundary(generation, nextUserId)) {
        return generation;
      }
      if (nextUserId != null) {
        _ref
            .read(authSessionBoundaryProvider.notifier)
            .markStorageReady(generation);
      }

      if (!isStartup && nextUserId != null) {
        try {
          _ref.invalidate(stateBootstrapProvider);
          await _ref.read(stateBootstrapProvider.future);
        } on Object catch (error, stackTrace) {
          Logger.errorCategory(
            'Auth Session',
            'New-account state bootstrap failed.',
            error,
            stackTrace,
          );
          _ref
              .read(authSessionBoundaryProvider.notifier)
              .block(
                generation,
                issue:
                    'ChronoSpark could not hydrate the authenticated account '
                    'state safely. Restart the app before continuing.',
              );
          return generation;
        }
      }

      _ref
          .read(authSessionBoundaryProvider.notifier)
          .complete(generation, storageReady: nextUserId != null);
      if (nextUserId != null) {
        FirebaseSupabaseBridgeRepository.resumeSessionWrites();
      }
      return generation;
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'Auth Session',
        'Authentication transition isolation failed.',
        error,
        stackTrace,
      );
      _ref.read(authSessionBoundaryProvider.notifier).block(generation);
      return generation;
    }
  }

  Future<int> _recoverMismatchedAuthenticatedSessionSerial() async {
    final AuthSessionBoundary blocked = _ref.read(authSessionBoundaryProvider);
    if (!blocked.canRecoverBySigningOut) {
      return blocked.generation;
    }

    final SessionRecoveryService previousSessionRecovery = _ref.read(
      sessionRecoveryProvider,
    );
    final int generation = _ref
        .read(authSessionBoundaryProvider.notifier)
        .begin(userId: null, isTransitioning: true);
    try {
      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      await _cancelAndDrainIdentityOwnedWork(
        sessionRecovery: previousSessionRecovery,
      );
      _invalidateIdentityOwnedState();
      _setIdentity(null);

      final authService = _ref.read(authServiceProvider);
      await authService.signOut();
      if (_normalizedUserId(authService.currentUser) != null) {
        throw StateError(
          'The mismatched authentication session remained active.',
        );
      }

      // Deliberately retain the authenticated owner marker and all local-first
      // data. Only the incoming remote session is removed.
      _currentUserId = null;
      _initialized = true;
      _ref
          .read(authSessionBoundaryProvider.notifier)
          .complete(generation, storageReady: false);
      return generation;
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'Auth Session',
        'Mismatched authenticated session recovery failed.',
        error,
        stackTrace,
      );
      _ref
          .read(authSessionBoundaryProvider.notifier)
          .block(
            generation,
            canRecoverBySigningOut: true,
            issue:
                'ChronoSpark could not sign out the blocked account safely. '
                'The owning account data remains preserved; retry sign-out before continuing.',
          );
      return generation;
    }
  }

  Future<int> _discardPreservedLegacyDataSerial() async {
    final AuthSessionBoundary blocked = _ref.read(authSessionBoundaryProvider);
    final User? currentUser = _ref.read(authServiceProvider).currentUser;
    final String? currentUserId = _normalizedUserId(currentUser);
    if (!blocked.canDiscardPreservedLegacyData || currentUserId == null) {
      return blocked.generation;
    }

    final _SessionOwnershipStore ownershipStore = _ref.read(
      _sessionOwnershipStoreProvider,
    );
    final _SessionOwnerRecord owner = await ownershipStore.readOwner();
    if (!owner.isUnverified) {
      _ref
          .read(authSessionBoundaryProvider.notifier)
          .block(
            blocked.generation,
            canRecoverBySigningOut: true,
            issue:
                'ChronoSpark could not verify the preserved legacy-data claim. Sign out the blocked account and retry.',
          );
      return blocked.generation;
    }

    bool localDataCleared = false;
    try {
      final authService = _ref.read(authServiceProvider);
      final User? preflightUser = await authService.reloadCurrentUser();
      if (_normalizedUserId(preflightUser) != currentUserId) {
        throw StateError(
          'The authenticated session could not be verified before local cleanup.',
        );
      }
      final int cleanupGeneration = _ref
          .read(authSessionBoundaryProvider.notifier)
          .begin(userId: currentUserId, isTransitioning: true);
      FirebaseSupabaseBridgeRepository.suspendSessionWrites();
      await _cancelAndDrainIdentityOwnedWork();
      _invalidateIdentityOwnedState();
      await _ref.read(_authTransitionCleanupProvider).clear();
      localDataCleared = true;
      final User? refreshedUser = await authService.reloadCurrentUser();
      if (_normalizedUserId(refreshedUser) != currentUserId) {
        throw StateError(
          'The authenticated session could not be restored after local cleanup.',
        );
      }
      await ownershipStore.claimUser(currentUserId);
      _initialized = false;
      _currentUserId = null;
      _ref
          .read(authSessionBoundaryProvider.notifier)
          .complete(cleanupGeneration, storageReady: false);
      return _transitionSerial(refreshedUser, isStartup: false);
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'Auth Session',
        'Preserved legacy-data discard failed.',
        error,
        stackTrace,
      );
      if (localDataCleared) {
        await ownershipStore.claimSignedOut();
        try {
          await _ref.read(authServiceProvider).signOut();
        } on Object {
          // The local data is already gone; the next launch will reconcile
          // any remaining remote session without exposing legacy content.
        }
        _currentUserId = null;
        _initialized = true;
        final int generation = _ref
            .read(authSessionBoundaryProvider.notifier)
            .begin(userId: null, isTransitioning: false);
        _ref
            .read(authSessionBoundaryProvider.notifier)
            .complete(generation, storageReady: false);
        return generation;
      }
      final int generation = _ref
          .read(authSessionBoundaryProvider.notifier)
          .begin(userId: currentUserId, isTransitioning: false);
      _ref
          .read(authSessionBoundaryProvider.notifier)
          .block(
            generation,
            canRecoverBySigningOut: true,
            canDiscardPreservedLegacyData: true,
            issue:
                'ChronoSpark could not delete the quarantined legacy data safely. Retry or sign out the blocked account.',
          );
      return generation;
    }
  }

  bool isCurrent(int generation, String? userId) {
    final AuthSessionBoundary boundary = _ref.read(authSessionBoundaryProvider);
    return _matchesBoundary(generation, userId) &&
        boundary.blockingIssue == null &&
        !boundary.isTransitioning;
  }

  bool _matchesBoundary(int generation, String? userId) {
    final AuthSessionBoundary boundary = _ref.read(authSessionBoundaryProvider);
    return boundary.generation == generation && boundary.userId == userId;
  }

  Future<void> _cancelAndDrainIdentityOwnedWork({
    SessionRecoveryService? sessionRecovery,
  }) async {
    final authService = _ref.read(authServiceProvider);
    final syncActions = _ref.read(syncActionsProvider);
    final ProfileController profile = _ref.read(profileProvider.notifier);
    final LearningController learning = _ref.read(learningProvider.notifier);
    final taskRepository = _ref.read(taskRepositoryProvider);
    final goalRepository = _ref.read(goalRepositoryProvider);
    final habitRepository = _ref.read(habitRepositoryProvider);
    final planRepository = _ref.read(planRepositoryProvider);
    final settingsRepository = _ref.read(settingsRepositoryProvider);
    final syncMutationDispatcher = _ref.read(syncMutationDispatcherProvider);
    final SessionRecoveryService recovery =
        sessionRecovery ?? _ref.read(sessionRecoveryProvider);
    await Future.wait<void>(<Future<void>>[
      taskRepository.cancelAndDrain(),
      goalRepository.cancelAndDrain(),
      habitRepository.cancelAndDrain(),
      planRepository.cancelAndDrain(),
      settingsRepository.cancelAndDrain(),
      syncMutationDispatcher.cancelAndDrain(),
      recovery.cancelAndDrain(),
      syncActions.cancelAndDrain(),
      cancelAndDrainExtendedDomainSessionState(_ref),
      profile.cancelAndDrainWrites(),
      learning.cancelAndDrainWrites(),
      _ref.read(firebaseSupabaseBridgeRepositoryProvider).drainMutations(),
      _ref.read(reminderOrchestratorServiceProvider).cancelAndDrain(),
      if (authService is AuthService)
        authService.cancelAndDrainProfileHydration(),
    ]);
  }

  void _setIdentity(User? user) {
    _ref
        .read(identityAccountProvider.notifier)
        .synchronizeAuthenticatedUser(user);
  }

  void _invalidateIdentityOwnedState() {
    // Dispose command/async state first so old-user work cannot publish into
    // the new session while source providers are being reset.
    _ref.invalidate(ai.aiResponseProvider);
    _ref.invalidate(ai.aiDecisionProvider);
    _ref.invalidate(ai.siEngineStateProvider);
    _ref.invalidate(ai.siOutputBundleProvider);
    _ref.invalidate(ai.aiControllerProvider);
    _ref.invalidate(ai.aiAgentTraceProvider);
    _ref.invalidate(ai.aiPersonalityProvider);
    _ref.invalidate(ai.aiExecutionStatusProvider);
    _ref.invalidate(ai.aiInputProvider);
    _ref.invalidate(ai.aiTriggerProvider);
    _ref.invalidate(ai.aiMessageThrottleProvider);
    _ref.invalidate(ai.aiSuggestionRateLimiterProvider);
    _ref.invalidate(authControllerProvider);
    _ref.invalidate(stateBootstrapProvider);
    _ref.invalidate(voiceControllerProvider);
    _ref.invalidate(voiceServiceProvider);
    _ref.invalidate(voiceCommandHandoffProvider);
    _ref.invalidate(firebaseSupabaseBridgeProvider);
    _ref.invalidate(reminderOrchestratorServiceProvider);
    _ref.invalidate(taskRepositoryProvider);
    _ref.invalidate(goalRepositoryProvider);
    _ref.invalidate(domainTaskRepositoryProvider);
    _ref.invalidate(domainGoalRepositoryProvider);
    _ref.invalidate(getTasksUseCaseProvider);
    _ref.invalidate(getGoalsUseCaseProvider);
    _ref.invalidate(createTaskUseCaseProvider);
    _ref.invalidate(completeTaskUseCaseProvider);
    _ref.invalidate(updateTaskUseCaseProvider);
    _ref.invalidate(featureCreateGoalUseCaseProvider);
    _ref.invalidate(featureUpdateGoalUseCaseProvider);
    _ref.invalidate(deleteGoalUseCaseProvider);
    _ref.invalidate(completeGoalUseCaseProvider);
    _ref.invalidate(habitRepositoryProvider);
    _ref.invalidate(timelineRepositoryProvider);
    _ref.invalidate(viewTimelineUsecaseProvider);
    _ref.invalidate(completionEventRepositoryProvider);
    _ref.invalidate(planRepositoryProvider);
    _ref.invalidate(settingsRepositoryProvider);
    _ref.invalidate(syncMutationDispatcherProvider);
    _ref.invalidate(sessionRecoveryProvider);
    _ref.invalidate(siEngineDependenciesProvider);
    _ref.invalidate(siEngineServiceProvider);

    _ref.invalidate(tasksProvider);
    _ref.invalidate(goalsProvider);
    _ref.invalidate(goalProgressProvider);
    _ref.invalidate(timelineProvider);
    _ref.invalidate(habitsProvider);
    _ref.invalidate(domainPlanRepositoryProvider);
    _ref.invalidate(getPlanUseCaseProvider);
    _ref.invalidate(createPlanUseCaseProvider);
    _ref.invalidate(updatePlanUseCaseProvider);
    _ref.invalidate(projectsProvider);
    _ref.invalidate(routinesProvider);
    _ref.invalidate(subtasksProvider);
    _ref.invalidate(profileProvider);
    _ref.invalidate(profileValuesProvider);
    _ref.invalidate(progressionProvider);
    _ref.invalidate(completionEventsProvider);
    _ref.invalidate(memoriesProvider);
    _ref.invalidate(milestonesProvider);
    _ref.invalidate(logsProvider);
    _ref.invalidate(notificationProvider);
    invalidateExtendedDomainSessionState(_ref);

    _ref.invalidate(behaviorStateProvider);
    _ref.invalidate(identityStateProvider);
    _ref.invalidate(identityAccountProvider);
    _ref.invalidate(identityAccountActionsProvider);
    _ref.invalidate(identityBootstrapProvider);
    _ref.invalidate(appStartupProvider);
    _ref.invalidate(accountConnectionProvider);
    _ref.invalidate(accountSecurityProvider);
    _ref.invalidate(chronoSparkPassportProvider);
    _ref.invalidate(learningProvider);
    _ref.invalidate(learningHistoryProvider);
    _ref.invalidate(siStateProvider);
    _ref.invalidate(siMemoryProvider);
    _ref.invalidate(sessionScoreProvider);
    _ref.invalidate(momentumProvider);
    _ref.invalidate(emotionProvider);
    _ref.invalidate(soulMapProfileProvider);
    invalidateInsightsSessionState(_ref);
    _ref.invalidate(optimizationConfigProvider);
    _ref.invalidate(trajectorySummaryProvider);
    _ref.invalidate(predictionProvider);

    _ref.invalidate(siStateAggregationProvider);
    _ref.invalidate(siDecisionOutputProvider);
    _ref.invalidate(smartCoachScreenModelProvider);
    _ref.invalidate(nexusScreenModelProvider);
    _ref.invalidate(siConsoleScreenModelProvider);
    _ref.invalidate(appFlowProvider);
    _ref.invalidate(supabaseMetricsRealtimeProvider);
    _ref.invalidate(supabaseBackendHealthProvider);
    _ref.invalidate(supabaseSyncQueueCountProvider);
    _ref.invalidate(flushSupabaseSyncQueueProvider);
    _ref.invalidate(syncActionsProvider);
    _ref.invalidate(syncServiceProvider);
    _ref.invalidate(syncToCloudProvider);
    _ref.invalidate(replayOfflineQueueProvider);
    _ref.invalidate(offlineQueueCountProvider);
    _ref.invalidate(restoreFromCloudProvider);
    _ref.invalidate(syncErrorMessageProvider);

    invalidateMonetizationSessionState(_ref);
    _ref.invalidate(legacy_paywall.aiCreditWalletProvider);
    _ref.invalidate(legacy_paywall.paywallSubscriptionProvider);
    _ref.invalidate(legacy_paywall.paywallConfigProvider);
    _ref.invalidate(legacy_paywall.paywallPromptProvider);
    _ref.invalidate(appAccessProvider);

    _ref.invalidate(tutorialProgressProvider);
    _ref.invalidate(tutorialControllerProvider);
    _ref.invalidate(missionStateProvider);
    _ref.invalidate(missionControllerProvider);

    _ref.read(onboardingCompleteProvider.notifier).set(false);
    _ref.read(onboardingStatusProvider.notifier).set(OnboardingStatus.unknown);
    _ref.read(creatorFirstItemCreatedProvider.notifier).set(false);
    _ref.read(timelineFirstActionCompletedProvider.notifier).set(false);
  }
}

String? _normalizedUserId(User? user) {
  final String id = user?.id.trim() ?? '';
  return id.isEmpty ? null : id;
}

bool? _coerceStoredBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  if (value is num) {
    if (value == 1) {
      return true;
    }
    if (value == 0) {
      return false;
    }
  }
  return null;
}

int? _coerceStoredInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

String _safeStorageScope(String userId) {
  return userId.trim().replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
}
