import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const ValueKey<String> _pageKey = ValueKey<String>('shared-shell-page');

void main() {
  late GoRouter router;
  late ProviderContainer container;
  late List<String> visits;

  Future<void> pumpApp(WidgetTester tester) async {
    visits = <String>[];
    container = ProviderContainer();
    addTearDown(container.dispose);
    router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => NoTransitionPage<void>(
            key: _pageKey,
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  const Text('home page'),
                  Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () =>
                          goToAppView(context, ref, AppView.trajectoryEngine),
                      child: const Text('go from home'),
                    ),
                  ),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            body: Consumer(
                              builder: (context, ref, _) => TextButton(
                                onPressed: () => goToAppView(
                                  context,
                                  ref,
                                  AppView.trajectoryEngine,
                                ),
                                child: const Text('go from pushed'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('push screen'),
                    ),
                  ),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          content: Consumer(
                            builder: (context, ref, _) => TextButton(
                              onPressed: () => goToAppView(
                                context,
                                ref,
                                AppView.trajectoryEngine,
                              ),
                              child: const Text('go from dialog'),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('open dialog'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/trajectory',
          pageBuilder: (context, state) {
            visits.add(state.uri.path);
            return const NoTransitionPage<void>(
              key: _pageKey,
              child: Scaffold(body: Text('trajectory page')),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing pushed it only navigates', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('go from home'));
    await tester.pumpAndSettle();

    expect(find.text('trajectory page'), findsOneWidget);
    expect(visits, <String>['/trajectory']);
    expect(container.read(appFlowProvider), isNot(AppView.trajectoryEngine));
  });

  testWidgets('a pushed screen is closed before the destination opens', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('push screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go from pushed'));
    await tester.pumpAndSettle();

    expect(find.text('go from pushed'), findsNothing);
    expect(find.text('trajectory page'), findsOneWidget);
    final BuildContext page = tester.element(find.text('trajectory page'));
    expect(ModalRoute.of(page)!.isCurrent, isTrue);
  });

  testWidgets('an open dialog is closed rather than orphaned', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go from dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('trajectory page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a router it falls back to the app flow state', (
    tester,
  ) async {
    final ProviderContainer flow = ProviderContainer();
    addTearDown(flow.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: flow,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  goToAppView(context, ref, AppView.trajectoryEngine),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    expect(flow.read(appFlowProvider), AppView.trajectoryEngine);
  });
}
