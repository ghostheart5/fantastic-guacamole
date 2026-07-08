import 'package:fantastic_guacamole/core/network/network_status_service.dart';
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

    expect(find.text('Offline Mode — actions will sync later'), findsOneWidget);
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

    expect(find.text('Offline Mode — actions will sync later'), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('announces offline banner with live region semantics', (WidgetTester tester) async {
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
      expect(node.label, 'Offline mode. Actions will sync later.');
    } finally {
      handle.dispose();
    }
  });
}
