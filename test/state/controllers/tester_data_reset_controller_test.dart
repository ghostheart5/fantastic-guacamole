import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/tester_data_reset_provider.dart';
import 'package:fantastic_guacamole/state/services/tester_data_reset_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset triggers reset service and clears key local state', () async {
    final _FakeTesterDataResetService fakeService =
        _FakeTesterDataResetService();
    final _FakeNotificationRepository notifications =
        _FakeNotificationRepository();
    final SecureStore inMemorySecureStore = SecureStore(
      backend: InMemorySecureStoreBackend(),
    );
    const String legacySiStateKey = 'si_engine_state_v1';
    await inMemorySecureStore.writeString(
      legacySiStateKey,
      '{"memory":"must be cleared"}',
    );

    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(inMemorySecureStore),
        testerDataResetServiceProvider.overrideWithValue(fakeService),
        domainNotificationRepositoryProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);

    container.read(mockSignInProvider.notifier).set(true);
    container.read(onboardingCompleteProvider.notifier).set(true);
    container.read(aiInputProvider.notifier).set('draft prompt');
    await container.read(notificationProvider.notifier).pushDecision('Task A');

    expect(container.read(notificationProvider), isNotEmpty);

    await container.read(testerDataResetControllerProvider).reset();

    expect(fakeService.resetCalled, isTrue);
    expect(container.read(mockSignInProvider), isFalse);
    expect(container.read(onboardingCompleteProvider), isFalse);
    expect(container.read(aiInputProvider), isNull);
    expect(container.read(notificationProvider), isEmpty);
    expect(await inMemorySecureStore.readString(legacySiStateKey), isNull);
  });
}

class _FakeTesterDataResetService extends TesterDataResetService {
  _FakeTesterDataResetService()
    : super(
        preferences: _NoopPrefsStore(),
        sensitivePreferences: _NoopPrefsStore(),
        hive: _NoopHiveStore(),
        secureStore: SecureStore(backend: InMemorySecureStoreBackend()),
        scope: AccountStorageScope.authenticated('account-a'),
      );

  bool resetCalled = false;

  @override
  Future<void> reset() async {
    resetCalled = true;
  }
}

class _NoopPrefsStore implements SharedPrefsStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => null;

  @override
  Future<void> save(String key, String value) async {}
}

class _NoopHiveStore implements HiveStore {
  @override
  Never box<T>(String key) => throw UnimplementedError();

  @override
  Future<void> clearBox(String key) async {}

  @override
  Future<void> closeBox(String key) async {}

  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => false;

  @override
  Future<Box<T>> openBox<T>(String key) async => throw UnimplementedError();
}

class _FakeNotificationRepository implements INotificationRepository {
  final Map<String, NotificationEntity> _entries =
      <String, NotificationEntity>{};

  @override
  Future<void> cancelNotification(String id) async {
    _entries.remove(id);
  }

  @override
  Future<void> delete(String id) async {
    _entries.remove(id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    return _entries.values.toList(growable: false);
  }

  @override
  Future<void> markRead(String id) async {
    final NotificationEntity? existing = _entries[id];
    if (existing == null) {
      return;
    }
    _entries[id] = NotificationEntity(
      id: existing.id,
      title: existing.title,
      message: existing.message,
      scheduledAt: existing.scheduledAt,
      isEnabled: existing.isEnabled,
      isRead: true,
    );
  }

  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {
    _entries[notification.id] = notification;
  }
}
