import 'package:fantastic_guacamole/app/startup/startup_notice_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (Size size, double scale) in <(Size, double)>[
    (const Size(432, 984), 1),
    (const Size(320, 568), 2),
    (const Size(640, 320), 2),
  ]) {
    testWidgets('notice leaves navigation usable at $size and scale $scale', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int timelineTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: StartupNoticeLayout(
            message:
                'App started in limited mode. '
                'Some services may be unavailable.',
            child: Scaffold(
              body: const Center(child: Text('Home')),
              bottomNavigationBar: TextButton(
                onPressed: () => timelineTaps++,
                child: const Text('Timeline'),
              ),
            ),
          ),
        ),
      );

      final Finder message = find.textContaining('App started');
      final Finder navigation = find.widgetWithText(TextButton, 'Timeline');
      expect(
        tester.getRect(navigation).bottom,
        lessThanOrEqualTo(tester.getRect(message).top),
      );
      await tester.tap(navigation);
      await tester.pump();
      expect(timelineTaps, 1);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('dismiss-startup-notice')));
      await tester.pump();
      expect(message, findsNothing);
      await tester.tap(navigation);
      expect(timelineTaps, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dismissal preserves route state and a new issue reappears', (
    WidgetTester tester,
  ) async {
    final GlobalKey<_RouteState> routeKey = GlobalKey<_RouteState>();
    Future<void> pumpNotice(String message) => tester.pumpWidget(
      MaterialApp(
        home: StartupNoticeLayout(
          message: message,
          child: _Route(key: routeKey),
        ),
      ),
    );
    await pumpNotice('Startup issue one');
    final _RouteState? originalState = routeKey.currentState;
    await tester.tap(find.byKey(const Key('dismiss-startup-notice')));
    await tester.pump();
    await pumpNotice('Startup issue one');
    expect(find.text('Startup issue one'), findsNothing);
    expect(routeKey.currentState, same(originalState));
    await pumpNotice('Startup issue two');
    expect(find.text('Startup issue two'), findsOneWidget);
    expect(routeKey.currentState, same(originalState));
    await pumpNotice('');
    expect(find.byKey(const Key('dismiss-startup-notice')), findsNothing);
    expect(routeKey.currentState, same(originalState));
  });
}

class _Route extends StatefulWidget {
  const _Route({super.key});

  @override
  State<_Route> createState() => _RouteState();
}

class _RouteState extends State<_Route> {
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home'));
}
