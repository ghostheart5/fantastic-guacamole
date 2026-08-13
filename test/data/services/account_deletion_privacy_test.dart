import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/services/local_user_data_cleanup_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/data/storage/storage_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

class _RecordingPreferences implements SharedPrefsStore {
  bool failClear = false;
  int initCalls = 0;
  int clearCalls = 0;

  @override
  Future<void> init() async => initCalls += 1;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    if (failClear) throw StateError('preferences clear failed');
  }

  @override
  Future<void> delete(String key) async {}

  @override
  String? load(String key) => null;

  @override
  Future<void> save(String key, String value) async {}
}

class _RecordingHiveStore implements HiveStore {
  final Set<String> clearedBoxes = <String>{};
  final Set<String> failingBoxes = <String>{};
  int initCalls = 0;

  @override
  Future<void> init() async => initCalls += 1;

  @override
  Future<void> clearBox(String key) async {
    clearedBoxes.add(key);
    if (failingBoxes.contains(key)) throw StateError('box clear failed');
  }

  @override
  Box<T> box<T>(String key) => throw UnsupportedError('not used');

  @override
  Future<void> closeBox(String key) async {}

  @override
  bool isBoxOpen(String key) => false;

  @override
  Future<Box<T>> openBox<T>(String key) => throw UnsupportedError('not used');
}

class _RecordingSecureBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  bool failDeleteAll = false;
  int deleteAllCalls = 0;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async {
    deleteAllCalls += 1;
    values.clear();
    if (failDeleteAll) throw StateError('secure clear failed');
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  group('account deletion reauthentication policy', () {
    test('classifies the supported Supabase providers', () {
      User userFor({String? primary, List<String> providers = const []}) {
        return User(
          id: 'user',
          emailVerified: true,
          authenticationProvider: primary,
          authenticationProviders: providers,
        );
      }

      expect(
        userFor(primary: 'email').accountDeletionReauthenticationMethod,
        AccountDeletionReauthenticationMethod.password,
      );
      expect(
        userFor(
          providers: const <String>['google'],
        ).accountDeletionReauthenticationMethod,
        AccountDeletionReauthenticationMethod.recentGoogleSignIn,
      );
      expect(
        userFor(primary: 'phone').accountDeletionReauthenticationMethod,
        AccountDeletionReauthenticationMethod.recentPhoneSignIn,
      );
      expect(
        userFor(
          providers: const <String>['email', 'google'],
        ).accountDeletionReauthenticationMethod,
        AccountDeletionReauthenticationMethod.unsupported,
      );
      expect(
        userFor(
          primary: 'google',
          providers: const <String>['google', 'email'],
        ).accountDeletionReauthenticationMethod,
        AccountDeletionReauthenticationMethod.unsupported,
      );
    });

    test('recent sign-in window is strict and clock-skew bounded', () {
      final DateTime now = DateTime.utc(2026, 8, 9, 18);

      expect(
        isAccountDeletionSignInRecent(
          now.subtract(
            const Duration(minutes: 10) - const Duration(milliseconds: 1),
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        isAccountDeletionSignInRecent(
          now.subtract(defaultAccountDeletionRecentSignInWindow),
          now: now,
        ),
        isFalse,
      );
      expect(
        isAccountDeletionSignInRecent(
          now.add(defaultAccountDeletionAllowedClockSkew),
          now: now,
        ),
        isTrue,
      );
      expect(
        isAccountDeletionSignInRecent(
          now.add(
            defaultAccountDeletionAllowedClockSkew +
                const Duration(milliseconds: 1),
          ),
          now: now,
        ),
        isFalse,
      );
      expect(isAccountDeletionSignInRecent(null, now: now), isFalse);
    });
  });

  group('local account privacy cleanup', () {
    test(
      'prepares sign-out by clearing only external account artifacts',
      () async {
        final _RecordingPreferences preferences = _RecordingPreferences();
        final _RecordingHiveStore hive = _RecordingHiveStore();
        final _RecordingSecureBackend backend = _RecordingSecureBackend();
        final List<String> actions = <String>[];
        final LocalUserDataCleanupService service = LocalUserDataCleanupService(
          preferences: preferences,
          hive: hive,
          secureStore: SecureStore(backend: backend),
          clearNotificationRoutingState: () async => actions.add('routing'),
          cancelNotifications: () async => actions.add('notifications'),
          disassociateFirebaseMessagingToken: () async =>
              actions.add('disassociate'),
          deleteFirebaseMessagingToken: () async => actions.add('token'),
        );

        await service.prepareForSignOut();

        expect(actions, <String>[
          'routing',
          'notifications',
          'disassociate',
          'token',
        ]);
        expect(preferences.initCalls, 0);
        expect(preferences.clearCalls, 0);
        expect(hive.clearedBoxes, isEmpty);
        expect(backend.deleteAllCalls, 0);
      },
    );

    test(
      'reports sign-out preparation failures after attempting every step',
      () async {
        final List<String> actions = <String>[];
        final LocalUserDataCleanupService service = LocalUserDataCleanupService(
          preferences: _RecordingPreferences(),
          hive: _RecordingHiveStore(),
          secureStore: SecureStore(backend: _RecordingSecureBackend()),
          clearNotificationRoutingState: () async => actions.add('routing'),
          cancelNotifications: () async {
            actions.add('notifications');
            throw StateError('notification cancellation failed');
          },
          disassociateFirebaseMessagingToken: () async =>
              actions.add('disassociate'),
          deleteFirebaseMessagingToken: () async => actions.add('token'),
        );

        final Object error = await service
            .prepareForSignOut()
            .then<Object>((_) => StateError('expected cleanup to fail'))
            .catchError((Object error) => error);

        expect(error, isA<LocalUserDataCleanupException>());
        expect((error as LocalUserDataCleanupException).failedSteps, <String>[
          'scheduled notifications',
        ]);
        expect(actions, <String>[
          'routing',
          'notifications',
          'disassociate',
          'token',
        ]);
      },
    );

    test('purges every declared store and external account artifact', () async {
      final _RecordingPreferences preferences = _RecordingPreferences();
      final _RecordingHiveStore hive = _RecordingHiveStore();
      final _RecordingSecureBackend backend = _RecordingSecureBackend();
      backend.values.addAll(<String, String>{
        HiveService.cipherStoreKey: 'device-cipher',
        'sensitive_preferences_v1': 'private-user-data',
      });
      final List<String> actions = <String>[];
      final LocalUserDataCleanupService service = LocalUserDataCleanupService(
        preferences: preferences,
        hive: hive,
        secureStore: SecureStore(backend: backend),
        clearNotificationRoutingState: () async => actions.add('routing'),
        cancelNotifications: () async => actions.add('notifications'),
        disassociateFirebaseMessagingToken: () async =>
            actions.add('disassociate'),
        deleteFirebaseMessagingToken: () async => actions.add('token'),
      );

      await service.clear(userId: 'user-1');

      expect(hive.clearedBoxes, <String>{
        ...HiveBoxes.encryptedBoxes,
        'profile_box',
        'tasks',
        StorageKeys.credentials,
        StorageKeys.session,
        StorageKeys.identity,
        StorageKeys.theme,
        StorageKeys.settings,
      });
      expect(preferences.initCalls, 1);
      expect(preferences.clearCalls, 1);
      expect(backend.deleteAllCalls, 1);
      expect(backend.values, <String, String>{
        HiveService.cipherStoreKey: 'device-cipher',
      });
      expect(actions, <String>[
        'routing',
        'notifications',
        'disassociate',
        'token',
      ]);
    });

    test('attempts every mandatory step and reports all failures', () async {
      final _RecordingPreferences preferences = _RecordingPreferences()
        ..failClear = true;
      final _RecordingHiveStore hive = _RecordingHiveStore()
        ..failingBoxes.add(HiveBoxes.habits);
      final _RecordingSecureBackend backend = _RecordingSecureBackend()
        ..failDeleteAll = true;
      final List<String> actions = <String>[];
      final LocalUserDataCleanupService service = LocalUserDataCleanupService(
        preferences: preferences,
        hive: hive,
        secureStore: SecureStore(backend: backend),
        clearNotificationRoutingState: () async => actions.add('routing'),
        cancelNotifications: () async {
          actions.add('notifications');
          throw StateError('notification cancellation failed');
        },
        disassociateFirebaseMessagingToken: () async =>
            actions.add('disassociate'),
        deleteFirebaseMessagingToken: () async => actions.add('token'),
      );

      final Object error = await service
          .clear(userId: 'user-1')
          .then<Object>((_) => StateError('expected cleanup to fail'))
          .catchError((Object error) => error);

      expect(error, isA<LocalUserDataCleanupException>());
      final LocalUserDataCleanupException cleanupError =
          error as LocalUserDataCleanupException;
      expect(
        cleanupError.failedSteps,
        containsAll(<String>[
          'scheduled notifications',
          'Hive box ${HiveBoxes.habits}',
          'SharedPreferences',
          'secure storage',
        ]),
      );
      expect(hive.clearedBoxes, <String>{
        ...HiveBoxes.encryptedBoxes,
        'profile_box',
        'tasks',
        StorageKeys.credentials,
        StorageKeys.session,
        StorageKeys.identity,
        StorageKeys.theme,
        StorageKeys.settings,
      });
      expect(preferences.clearCalls, 1);
      expect(backend.deleteAllCalls, 1);
      expect(actions, <String>[
        'routing',
        'notifications',
        'disassociate',
        'token',
      ]);
    });
  });
}
