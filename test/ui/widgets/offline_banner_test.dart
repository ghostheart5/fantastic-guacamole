import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows banner when offline', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(false)],
        child: const MaterialApp(
          home: OfflineBanner(child: Scaffold(body: Text('content'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.text(
        'Offline Mode — local features available; cloud sync unavailable',
      ),
      findsOneWidget,
    );
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('hides banner when online', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(true)],
        child: const MaterialApp(
          home: OfflineBanner(child: Scaffold(body: Text('content'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.text(
        'Offline Mode — local features available; cloud sync unavailable',
      ),
      findsNothing,
    );
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('announces offline banner with live region semantics', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isOnlineProvider.overrideWithValue(false)],
          child: const MaterialApp(
            home: OfflineBanner(child: Scaffold(body: Text('content'))),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      final SemanticsNode node = tester.getSemantics(
        find.byKey(const Key('offline_banner_live_region')),
      );
      // ignore: deprecated_member_use
      expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      expect(
        node.label,
        'Offline mode. Local features remain available. Cloud sync is unavailable in this build.',
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('promises later sync only when cloud sync is available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isOnlineProvider.overrideWithValue(false),
          cloudSyncCapabilityProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          home: OfflineBanner(child: Scaffold(body: Text('content'))),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Offline Mode — actions will sync later'), findsOneWidget);
  });

  testWidgets('keeps the banner below the top inset and consumes it once', (
    WidgetTester tester,
  ) async {
    double? descendantTopPadding;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(false)],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: OfflineBanner(
              child: Builder(
                builder: (BuildContext context) {
                  descendantTopPadding = MediaQuery.paddingOf(context).top;
                  return const Scaffold(body: Text('content'));
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      tester.getTopLeft(find.byKey(const Key('offline_banner_live_region'))).dy,
      24,
    );
    expect(descendantTopPadding, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps the offline message on a narrow large-text surface', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    const String message =
        'Offline Mode — local features available; cloud sync unavailable';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(false)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: OfflineBanner(child: Scaffold(body: Text('content'))),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull);
    final Rect messageRect = tester.getRect(find.text(message));
    expect(messageRect.left, greaterThanOrEqualTo(0));
    expect(messageRect.right, lessThanOrEqualTo(320));
    expect(messageRect.height, greaterThan(22));
  });
}
