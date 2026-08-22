import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';

typedef LocalUserDataCleanupAction = Future<void> Function();

class LocalUserDataCleanupException implements Exception {
  LocalUserDataCleanupException(Iterable<String> failedSteps)
    : failedSteps = List<String>.unmodifiable(failedSteps);

  final List<String> failedSteps;

  @override
  String toString() {
    return 'Local user data cleanup failed for: ${failedSteps.join(', ')}';
  }
}

class LocalUserDataCleanupService {
  LocalUserDataCleanupService({
    required this.preferences,
    required this.hive,
    required this.secureStore,
    LocalUserDataCleanupAction? cancelNotifications,
    LocalUserDataCleanupAction? deleteFirebaseMessagingToken,
    LocalUserDataCleanupAction? disassociateFirebaseMessagingToken,
    LocalUserDataCleanupAction? clearNotificationRoutingState,
  }) : _cancelNotifications =
           cancelNotifications ??
           (() => NotificationScheduler().cancelAllForAccountRemoval()),
       _deleteFirebaseMessagingToken =
           deleteFirebaseMessagingToken ??
           (() => const FirebaseMessagingBootstrap()
               .deleteTokenForAccountRemoval()),
       _disassociateFirebaseMessagingToken =
           disassociateFirebaseMessagingToken ?? (() async {}),
       _clearNotificationRoutingState =
           clearNotificationRoutingState ??
           (() async => NotificationScheduler.clearAccountRoutingState());

  final SharedPrefsStore preferences;
  final HiveStore hive;
  final SecureStore secureStore;
  final LocalUserDataCleanupAction _cancelNotifications;
  final LocalUserDataCleanupAction _deleteFirebaseMessagingToken;
  final LocalUserDataCleanupAction _disassociateFirebaseMessagingToken;
  final LocalUserDataCleanupAction _clearNotificationRoutingState;

  static const Set<String> _additionalHiveBoxes = <String>{
    'profile_box',
    'tasks',
    StorageKeys.credentials,
    StorageKeys.session,
    StorageKeys.identity,
    StorageKeys.notifications,
    StorageKeys.theme,
    StorageKeys.settings,
  };

  Future<void> prepareForAccountDeletion() {
    return _runMandatorySteps(_externalCleanupSteps());
  }

  Future<void> prepareForSignOut() {
    return _runMandatorySteps(_externalCleanupSteps());
  }

  Future<void> clearLocalData({String? userId}) {
    _validateUserId(userId);
    return _runMandatorySteps(_localStorageCleanupSteps(userId: userId));
  }

  Future<void> clear({String? userId}) {
    _validateUserId(userId);
    return _runMandatorySteps(<String, LocalUserDataCleanupAction>{
      ..._externalCleanupSteps(),
      ..._localStorageCleanupSteps(userId: userId),
    });
  }

  Map<String, LocalUserDataCleanupAction> _externalCleanupSteps() {
    return <String, LocalUserDataCleanupAction>{
      'notification routing state': _clearNotificationRoutingState,
      'scheduled notifications': _cancelNotifications,
      'Supabase messaging-token association':
          _disassociateFirebaseMessagingToken,
      'Firebase messaging token': _deleteFirebaseMessagingToken,
    };
  }

  Map<String, LocalUserDataCleanupAction> _localStorageCleanupSteps({
    required String? userId,
  }) {
    final Set<String> hiveBoxes = <String>{
      ...HiveBoxes.encryptedBoxes,
      ..._additionalHiveBoxes,
      ..._accountScopedBoxesForUser(userId),
    };
    return <String, LocalUserDataCleanupAction>{
      'Hive initialization': hive.init,
      for (final String box in hiveBoxes)
        'Hive box $box': () => hive.clearBox(box),
      'SharedPreferences initialization': preferences.init,
      'SharedPreferences': preferences.clear,
      'secure storage': _clearSecureStoragePreservingHiveCipher,
    };
  }

  Set<String> _accountScopedBoxesForUser(String? userId) {
    if (userId == null) return const <String>{};
    final AccountStorageNamespace namespace =
        AccountStorageNamespace.authenticated(userId);
    return <String>{
      HiveBoxes.accountScopedNamespace(HiveBoxes.tasks, namespace.v2Scope),
      HiveBoxes.accountScopedNamespace(
        HiveBoxes.taskOccurrences,
        namespace.v2Scope,
      ),
      HiveBoxes.accountScopedNamespace(
        HiveBoxes.taskOccurrenceProjectionWork,
        namespace.v2Scope,
      ),
      HiveBoxes.accountScopedNamespace(HiveBoxes.notes, namespace.v2Scope),
      HiveBoxes.accountScopedNamespace(HiveBoxes.goals, namespace.v2Scope),
      HiveBoxes.accountScopedNamespace(HiveBoxes.habits, namespace.v2Scope),
      HiveBoxes.accountScopedNamespace(
        HiveBoxes.habitOccurrences,
        namespace.v2Scope,
      ),
      HiveBoxes.accountScopedNamespace(HiveBoxes.dailyPlans, namespace.v2Scope),
      HiveBoxes.accountScopedNamespace(
        HiveBoxes.offlineQueue,
        namespace.v2Scope,
      ),
    };
  }

  Future<void> _clearSecureStoragePreservingHiveCipher() async {
    final String? hiveCipher = await secureStore.readString(
      HiveService.cipherStoreKey,
    );
    await secureStore.deleteAll();
    if (hiveCipher != null && hiveCipher.trim().isNotEmpty) {
      await secureStore.writeString(HiveService.cipherStoreKey, hiveCipher);
    }
  }

  Future<void> _runMandatorySteps(
    Map<String, LocalUserDataCleanupAction> steps,
  ) async {
    final List<String> failedSteps = <String>[];
    for (final MapEntry<String, LocalUserDataCleanupAction> step
        in steps.entries) {
      try {
        await step.value();
      } on Object {
        failedSteps.add(step.key);
        Logger.warn('Mandatory local cleanup step failed: ${step.key}.');
      }
    }
    if (failedSteps.isNotEmpty) {
      throw LocalUserDataCleanupException(failedSteps);
    }
  }

  void _validateUserId(String? userId) {
    if (userId != null && userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be blank');
    }
  }
}
