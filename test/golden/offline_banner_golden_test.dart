import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('offline banner visual contract', () {
    testWidgets('offline queue state renders status copy', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final ProviderContainer container = ProviderContainer(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          offlineQueueCountProvider.overrideWith((Ref ref) async => 3),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(syncErrorMessageProvider.notifier)
          .set('Cloud sync failed. Retry queued.');

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
        find.text('Offline Mode - Cloud sync failed. Retry queued.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('offline_banner_live_region')), findsOneWidget);
    });
  });
}
