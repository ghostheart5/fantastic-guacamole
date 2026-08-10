import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmartPressable', () {
    testWidgets('invokes onTap once per tap', (WidgetTester tester) async {
      int taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartPressable(
              onTap: () => taps++,
              child: const Text('Press me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Press me'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('OfflineBanner', () {
    testWidgets('hides banner when online', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOnlineProvider.overrideWith((Ref ref) => true)],
          child: const MaterialApp(
            home: Scaffold(body: OfflineBanner(child: Text('Body'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Body'), findsOneWidget);
      expect(find.textContaining('Offline Mode'), findsNothing);
    });

    testWidgets('shows default offline message when offline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOnlineProvider.overrideWith((Ref ref) => false)],
          child: const MaterialApp(
            home: Scaffold(body: OfflineBanner(child: Text('Body'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Body'), findsOneWidget);
      expect(
        find.textContaining('Offline Mode - actions will sync later'),
        findsOneWidget,
      );
    });
  });
}
