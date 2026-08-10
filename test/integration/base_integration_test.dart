import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('base integration coverage', () {
    test('app flow controller supports primary navigation transitions', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appFlowProvider), AppView.nexus);
      container.read(appFlowProvider.notifier).toCreator();
      expect(container.read(appFlowProvider), AppView.creator);
      container.read(appFlowProvider.notifier).toTimeline();
      expect(container.read(appFlowProvider), AppView.timeline);
      container.read(appFlowProvider.notifier).toProfile();
      expect(container.read(appFlowProvider), AppView.profile);
    });

    testWidgets('offline banner shows queued message when offline', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          offlineQueueCountProvider.overrideWith((Ref ref) async => 3),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(syncErrorMessageProvider.notifier)
          .set('Cloud sync failed. retry queued.');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: OfflineBanner(child: SizedBox.expand())),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('offline_banner_live_region')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Offline Mode - Cloud sync failed. retry queued.'),
        findsOneWidget,
      );
    });
  });
}
