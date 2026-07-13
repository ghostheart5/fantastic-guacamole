import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tracks unread notifications through read and delete actions', () async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        domainNotificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(notificationProvider.notifier)
        .pushDecision('Prepare launch');

    final List<NotificationEntity> created = container.read(
      notificationProvider,
    );
    expect(
      created.where(
        (NotificationEntity item) => item.title == 'Decision Alert',
      ),
      isNotEmpty,
    );
    expect(
      container.read(unreadNotificationsProvider),
      greaterThanOrEqualTo(1),
    );

    final String id = created.first.id;
    await container.read(notificationProvider.notifier).markRead(id);

    final List<NotificationEntity> afterRead = container.read(
      notificationProvider,
    );
    final NotificationEntity marked = afterRead.firstWhere(
      (NotificationEntity item) => item.id == id,
    );
    expect(marked.isRead, isTrue);

    await container.read(notificationProvider.notifier).delete(id);
    expect(
      container
          .read(notificationProvider)
          .where((NotificationEntity item) => item.id == id),
      isEmpty,
    );
  });

  test(
    'keeps newly pushed notification when initial async load finishes late',
    () async {
      final _SnapshotDelayedNotificationRepository repository =
          _SnapshotDelayedNotificationRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          domainNotificationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(notificationProvider.notifier)
          .pushDecision('Lock sprint scope');
      await Future<void>.delayed(const Duration(milliseconds: 70));

      final List<NotificationEntity> notifications = container.read(
        notificationProvider,
      );
      expect(notifications, hasLength(1));
      expect(notifications.single.message, contains('Lock sprint scope'));
    },
  );

  test('push helper variants add expected notification titles', () async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        domainNotificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(notificationProvider.notifier)
        .pushCompletionFeedback('Task X');
    await container
        .read(notificationProvider.notifier)
        .pushTaskSkipped('Task Y');

    final List<NotificationEntity> notifications = container.read(
      notificationProvider,
    );
    expect(notifications, hasLength(2));
    expect(
      notifications.map((NotificationEntity item) => item.title),
      contains('Completion'),
    );
    expect(
      notifications.map((NotificationEntity item) => item.title),
      contains('Task Skipped'),
    );
  });

  test('clear removes all in-memory notifications', () async {
    final _FakeNotificationRepository repository =
        _FakeNotificationRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        domainNotificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(notificationProvider.notifier)
        .pushDecision('Reset target');
    expect(container.read(notificationProvider), isNotEmpty);

    container.read(notificationProvider.notifier).clear();
    expect(container.read(notificationProvider), isEmpty);
  });
}

class _FakeNotificationRepository implements INotificationRepository {
  final Map<String, NotificationEntity> _entries =
      <String, NotificationEntity>{};

  @override
  Future<void> cancelNotification(String id) async {
    final NotificationEntity? existing = _entries[id];
    if (existing == null) {
      return;
    }
    _entries[id] = NotificationEntity(
      id: existing.id,
      title: existing.title,
      message: existing.message,
      scheduledAt: existing.scheduledAt,
      isEnabled: false,
      isRead: existing.isRead,
    );
  }

  @override
  Future<void> delete(String id) async {
    _entries.remove(id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    final List<NotificationEntity> notifications = _entries.values.toList(
      growable: false,
    );
    notifications.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return notifications;
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

class _SnapshotDelayedNotificationRepository
    implements INotificationRepository {
  final Map<String, NotificationEntity> _entries =
      <String, NotificationEntity>{};

  @override
  Future<void> cancelNotification(String id) async {
    final NotificationEntity? existing = _entries[id];
    if (existing == null) {
      return;
    }
    _entries[id] = NotificationEntity(
      id: existing.id,
      title: existing.title,
      message: existing.message,
      scheduledAt: existing.scheduledAt,
      isEnabled: false,
      isRead: existing.isRead,
    );
  }

  @override
  Future<void> delete(String id) async {
    _entries.remove(id);
  }

  @override
  Future<List<NotificationEntity>> getNotifications() async {
    final List<NotificationEntity> snapshot = _entries.values.toList(
      growable: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    snapshot.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return snapshot;
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
