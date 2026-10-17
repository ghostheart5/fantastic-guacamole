import 'dart:ui' as ui;

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/services/unavailable_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _fixturePath = '/landscape-rail-fixture';
const Map<String, String> _destinations = <String, String>{
  'Nexus Core': RoutePaths.nexus,
  'Future Branches': RoutePaths.trajectoryEngine,
  'Truth Ledger': RoutePaths.timeline,
  'Human Profile': RoutePaths.profile,
};
const String _mapLabel = 'Open navigation map';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
  });

  // Native evidence is 2460x1080 at DPR2.5, hence 984x432 logical.
  // Insets below are representative regression inputs, not measured native values.
  for (final ({String name, Size size, EdgeInsets padding}) fixture
      in <({String name, Size size, EdgeInsets padding})>[
        (
          name: 'compact landscape left cutout',
          size: const Size(984, 432),
          padding: const EdgeInsets.fromLTRB(46, 0, 0, 24),
        ),
        (
          name: 'compact landscape right system bar',
          size: const Size(984, 432),
          padding: const EdgeInsets.fromLTRB(0, 0, 48, 24),
        ),
        (
          name: 'extended landscape with system insets',
          size: const Size(1200, 432),
          padding: const EdgeInsets.fromLTRB(46, 0, 48, 24),
        ),
      ]) {
    testWidgets(
      '${fixture.name}: five safe targets retain navigation actions',
      (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        _RailHarness? harness;
        try {
          harness = await _pumpRail(
            tester,
            size: fixture.size,
            padding: fixture.padding,
          );
          final Rect safeBounds = Rect.fromLTRB(
            fixture.padding.left,
            fixture.padding.top,
            fixture.size.width - fixture.padding.right,
            fixture.size.height - fixture.padding.bottom,
          );
          for (final String label in <String>[
            ..._destinations.keys,
            _mapLabel,
          ]) {
            _expectUsableControl(tester, label, safeBounds);
          }
          final Finder scroll = _railScroll();
          final Rect viewport = tester.getRect(scroll);
          final Rect mapRect = tester.getRect(_inkWell(_mapLabel));
          expect(mapRect.bottom, closeTo(viewport.bottom, 0.01));
          expect(
            find.byKey(const ValueKey<String>('phone-bottom-navigation')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);

          for (final MapEntry<String, String> destination
              in _destinations.entries) {
            await tester.tap(_inkWell(destination.key));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(
              harness.router.routeInformationProvider.value.uri.path,
              destination.value,
            );
            expect(
              find.byKey(ValueKey<String>(destination.value)),
              findsOneWidget,
            );
            harness.router.go(_fixturePath);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            _expectUsableControl(tester, destination.key, safeBounds);
          }
          await tester.tap(_inkWell(_mapLabel));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('System Map'), findsOneWidget);
          await tester.tap(find.byTooltip('Close navigation map'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('System Map'), findsNothing);
          expect(
            harness.router.routeInformationProvider.value.uri.path,
            _fixturePath,
          );
          expect(tester.takeException(), isNull);
        } finally {
          try {
            if (harness != null) {
              await harness.unmount(tester);
            }
          } finally {
            semantics.dispose();
          }
        }
      },
    );
  }

  testWidgets('compact rail scrolls full targets above a landscape keyboard', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    _RailHarness? harness;
    try {
      // Representative inset: actual LV04 IME height was not captured as MediaQuery.
      const double keyboardInset = 200;
      const Size size = Size(984, 432);
      const EdgeInsets padding = EdgeInsets.only(left: 46);
      harness = await _pumpRail(
        tester,
        size: size,
        padding: padding,
        keyboardInset: keyboardInset,
      );
      final Rect safeBounds = Rect.fromLTRB(
        46,
        0,
        size.width,
        size.height - keyboardInset,
      );
      final Finder scroll = _railScroll();
      final Finder scrollable = find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      );
      final ScrollableState state = tester.state<ScrollableState>(scrollable);
      expect(state.position.maxScrollExtent, greaterThan(0));
      for (final String label in <String>[..._destinations.keys, _mapLabel]) {
        await tester.ensureVisible(_inkWell(label));
        await tester.pump();
        _expectUsableControl(tester, label, safeBounds);
      }
      expect(state.position.pixels, greaterThan(0));
      await tester.ensureVisible(_inkWell('Nexus Core'));
      await tester.pump();
      _expectUsableControl(tester, 'Nexus Core', safeBounds);
      expect(tester.takeException(), isNull);
    } finally {
      try {
        if (harness != null) {
          await harness.unmount(tester);
        }
      } finally {
        semantics.dispose();
      }
    }
  });
}

Finder _inkWell(String label) =>
    find.descendant(of: find.byTooltip(label), matching: find.byType(InkWell));

Finder _railScroll() => find.ancestor(
  of: find.byTooltip(_mapLabel),
  matching: find.byType(SingleChildScrollView),
);

void _expectContained(Rect inner, Rect outer) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.01));
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.01));
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.01));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.01));
}

void _expectUsableControl(WidgetTester tester, String label, Rect safeBounds) {
  final Finder control = _inkWell(label);
  expect(control, findsOneWidget);
  expect(control.hitTestable(), findsOneWidget);
  final Rect hitbox = tester.getRect(control);
  expect(hitbox.width, greaterThanOrEqualTo(48));
  expect(hitbox.height, closeTo(56, 0.01));
  _expectContained(hitbox, safeBounds);
  final Rect viewport = tester.getRect(_railScroll());
  _expectContained(hitbox, viewport);
  final Finder icon = find.descendant(of: control, matching: find.byType(Icon));
  expect(icon, findsOneWidget);
  _expectContained(tester.getRect(icon), hitbox);
  _expectContained(tester.getRect(icon), viewport);
  final data = tester.getSemantics(find.byTooltip(label)).getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
  if (label != _mapLabel) {
    expect(
      data.flagsCollection.isSelected,
      label == 'Truth Ledger' ? ui.Tristate.isTrue : ui.Tristate.isFalse,
    );
  }
}

Future<_RailHarness> _pumpRail(
  WidgetTester tester, {
  required Size size,
  required EdgeInsets padding,
  double keyboardInset = 0,
}) async {
  tester.view
    ..physicalSize = size * 2.5
    ..devicePixelRatio = 2.5;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
  final ProviderContainer container = ProviderContainer(
    overrides: [
      // Layout fixture: no backend/auth timer or periodic authority refresh.
      authServiceProvider.overrideWithValue(const UnavailableAuthService()),
      entitlementAuthorityRecheckIntervalProvider.overrideWithValue(
        Duration.zero,
      ),
      networkInterfaceAvailabilityProvider.overrideWithValue(
        // The offline banner must not consume the fixture insets before the rail.
        NetworkInterfaceAvailability.unknown,
      ),
      hiveStoreProvider.overrideWithValue(_MemoryHiveStore()),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      sensitivePrefsStoreProvider.overrideWithValue(
        const SharedPrefsStoreAdapter(),
      ),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('landscape-rail-test-account'),
      ),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.provenNotOwned,
      ),
      unreadNotificationsProvider.overrideWithValue(0),
      goalsProvider.overrideWith(_StaticGoals.new),
    ],
  );
  final GoRouter router = GoRouter(
    initialLocation: _fixturePath,
    routes: <RouteBase>[
      GoRoute(
        path: _fixturePath,
        builder: (context, state) =>
            const NavigationShell(initialView: AppView.timeline),
      ),
      for (final String path in _destinations.values)
        GoRoute(
          path: path,
          builder: (context, state) =>
              Scaffold(body: SizedBox.expand(key: ValueKey<String>(path))),
        ),
    ],
  );
  final _RailHarness harness = _RailHarness(container, router);
  addTearDown(() async {
    await harness.unmount(tester);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: padding,
            viewPadding: padding,
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return harness;
}

class _RailHarness {
  _RailHarness(this.container, this.router);
  final ProviderContainer container;
  final GoRouter router;
  bool _disposed = false;

  Future<void> unmount(WidgetTester tester) async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    // Drain existing bounded background read deadlines after shell disposal.
    await tester.pump(const Duration(seconds: 15));
  }
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

class _MemoryHiveStore implements HiveStore {
  final Map<String, Box<dynamic>> _boxes = <String, Box<dynamic>>{};
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => _boxes.containsKey(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      _boxes.putIfAbsent(key, _MemoryBox<T>.new) as Box<T>;
  @override
  Box<T> box<T>(String key) => _boxes[key]! as Box<T>;
  @override
  Future<void> clearBox(String key) async {
    await _boxes[key]?.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    _boxes.remove(key);
  }
}

class _MemoryBox<T> implements Box<T> {
  final Map<dynamic, T> _values = <dynamic, T>{};
  @override
  T? get(dynamic key, {T? defaultValue}) => _values[key] ?? defaultValue;
  @override
  bool containsKey(dynamic key) => _values.containsKey(key);
  @override
  Iterable<dynamic> get keys => _values.keys;
  @override
  bool get isNotEmpty => _values.isNotEmpty;
  @override
  Map<dynamic, T> toMap() => Map<dynamic, T>.of(_values);
  @override
  Future<void> put(dynamic key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, T> values) async {
    _values.addAll(values);
  }

  @override
  Future<void> delete(dynamic key) async {
    _values.remove(key);
  }

  @override
  Future<int> clear() async {
    final int count = _values.length;
    _values.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
