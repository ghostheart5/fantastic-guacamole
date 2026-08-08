import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The notifications surface had no widget coverage. Both the empty state and
/// the populated list are first-run-visible, so both are pinned here.
void main() {
  Future<void> pumpNotifications(
    WidgetTester tester,
    List<NotificationEntity> items,
  ) async {
    tester.platformDispatcher.views.first
      ..physicalSize = const Size(1200, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(() {
      tester.platformDispatcher.views.first
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    final ProviderContainer container = ProviderContainer(
      overrides: [
        notificationProvider.overrideWith(() => _StaticNotifications(items)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a reassuring empty state when there is nothing pending', (
    WidgetTester tester,
  ) async {
    await pumpNotifications(tester, const <NotificationEntity>[]);

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('NO ALERTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders scheduled notifications', (WidgetTester tester) async {
    await pumpNotifications(tester, <NotificationEntity>[
      NotificationEntity(
        id: 'n-1',
        title: 'Daily reflection',
        message: 'Take two minutes to review today.',
        scheduledAt: DateTime.utc(2026, 8, 6, 20),
      ),
      NotificationEntity(
        id: 'n-2',
        title: 'Plan tomorrow',
        message: 'Set one priority for the morning.',
        scheduledAt: DateTime.utc(2026, 8, 6, 21),
        isRead: true,
      ),
    ]);

    expect(find.text('Daily reflection'), findsOneWidget);
    expect(find.text('Plan tomorrow'), findsOneWidget);
    expect(find.text('NO ALERTS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a disabled notification without crashing', (
    WidgetTester tester,
  ) async {
    // Cancelling a notification disables the record rather than deleting it,
    // so the disabled variant is a real state this list has to render.
    await pumpNotifications(tester, <NotificationEntity>[
      NotificationEntity(
        id: 'n-3',
        title: 'Cancelled reminder',
        message: 'This one was switched off.',
        scheduledAt: DateTime.utc(2026, 8, 6, 22),
        isEnabled: false,
      ),
    ]);

    expect(find.text('Cancelled reminder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StaticNotifications extends NotificationNotifier {
  _StaticNotifications(this._items);

  final List<NotificationEntity> _items;

  @override
  List<NotificationEntity> build() => _items;
}
