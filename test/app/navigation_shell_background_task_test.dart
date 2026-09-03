import 'dart:async';

import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/entitlement_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/services/app_recovery_service.dart';
import 'package:fantastic_guacamole/system/analytics/local_metrics_accumulator.dart';
import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runGuardedBackgroundTask', () {
    test('runs a successful task exactly once', () async {
      int calls = 0;

      await runGuardedBackgroundTask(
        label: 'successful test task',
        task: () async {
          calls += 1;
        },
      );

      expect(calls, 1);
    });

    test('contains synchronous task failures', () async {
      int calls = 0;

      await expectLater(
        runGuardedBackgroundTask(
          label: 'synchronous failure test task',
          task: () {
            calls += 1;
            throw StateError('synchronous test failure');
          },
        ),
        completes,
      );

      expect(calls, 1);
    });

    test('contains asynchronous task failures', () async {
      int calls = 0;

      await expectLater(
        runGuardedBackgroundTask(
          label: 'asynchronous failure test task',
          task: () async {
            calls += 1;
            await Future<void>.delayed(Duration.zero);
            throw Exception('asynchronous test failure');
          },
        ),
        completes,
      );

      expect(calls, 1);
    });
  });

  group('NavigationShell background containment', () {
    testWidgets('refreshes entitlement authority on resume only', (
      WidgetTester tester,
    ) async {
      int refreshCalls = 0;
      _entitlementRefreshProbe = ({bool force = false}) async {
        expect(force, isTrue);
        refreshCalls += 1;
      };
      await _pumpShell(tester, probeEntitlement: true);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(refreshCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(refreshCalls, 1);
    });

    testWidgets('forces entitlement authority refresh on reconnect', (
      WidgetTester tester,
    ) async {
      final StreamController<bool> network = StreamController<bool>();
      addTearDown(network.close);
      final List<bool> forces = <bool>[];
      _entitlementRefreshProbe = ({bool force = false}) async {
        forces.add(force);
      };
      await _pumpShell(tester, probeEntitlement: true, networkStatus: network);

      network.add(false);
      await tester.pump();
      network.add(true);
      await tester.pump();
      await tester.pump();

      expect(forces, <bool>[true]);
    });

    testWidgets('rechecks premium authority only while foregrounded', (
      WidgetTester tester,
    ) async {
      final List<bool> forces = <bool>[];
      _entitlementRefreshProbe = ({bool force = false}) async {
        forces.add(force);
      };
      await _pumpShell(
        tester,
        probeEntitlement: true,
        premiumAccess: true,
        authorityRecheckInterval: const Duration(seconds: 1),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(forces, <bool>[true]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(forces, <bool>[true]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('contains a rejected route recovery save', (
      WidgetTester tester,
    ) async {
      final _FakeRecoveryService recovery = _FakeRecoveryService(
        failOnSave: true,
      );
      final ProviderContainer container = await _pumpShell(
        tester,
        recovery: recovery,
      );

      container.read(appFlowProvider.notifier).show(AppView.timeline);
      await tester.pump();
      await tester.pump();

      expect(recovery.saveCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('contains a rejected lifecycle metrics snapshot', (
      WidgetTester tester,
    ) async {
      final _FakeMetricsAccumulator metrics = _FakeMetricsAccumulator(
        failOnSnapshot: true,
      );
      await _pumpShell(tester, metrics: metrics);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump();

      expect(metrics.snapshotCalls, 1);
      expect(tester.takeException(), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    testWidgets('contains a rejected audio interruption shutdown', (
      WidgetTester tester,
    ) async {
      final _FakeAudioInterruptionService audio = _FakeAudioInterruptionService(
        failOnStop: true,
      );
      await _pumpShell(tester, audio: audio);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(audio.stopCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  _FakeRecoveryService? recovery,
  _FakeMetricsAccumulator? metrics,
  _FakeAudioInterruptionService? audio,
  bool probeEntitlement = false,
  bool premiumAccess = false,
  Duration? authorityRecheckInterval,
  StreamController<bool>? networkStatus,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('navigation-background-test-account'),
      ),
      accountLegacyOwnershipProvider.overrideWithValue(
        LegacyScopeOwnership.provenNotOwned,
      ),
      unreadNotificationsProvider.overrideWithValue(0),
      goalsProvider.overrideWith(_StaticGoals.new),
      appRecoveryProvider.overrideWithValue(recovery ?? _FakeRecoveryService()),
      localMetricsAccumulatorProvider.overrideWithValue(
        metrics ?? _FakeMetricsAccumulator(),
      ),
      audioInterruptionServiceProvider.overrideWithValue(
        audio ?? _FakeAudioInterruptionService(),
      ),
      runtimePremiumAccessProvider.overrideWithValue(premiumAccess),
      if (authorityRecheckInterval != null)
        entitlementAuthorityRecheckIntervalProvider.overrideWithValue(
          authorityRecheckInterval,
        ),
      if (networkStatus != null)
        networkStatusProvider.overrideWith((ref) => networkStatus.stream),
      if (probeEntitlement)
        entitlementAuthorityRefreshProvider.overrideWithValue(
          _entitlementRefreshProbe,
        ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NavigationShell()),
    ),
  );
  await tester.pump();
  return container;
}

class _StaticGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => const <GoalEntity>[];
}

EntitlementAuthorityRefresh _entitlementRefreshProbe =
    ({bool force = false}) async {};

class _FakeRecoveryService extends AppRecoveryService {
  _FakeRecoveryService({this.failOnSave = false});

  final bool failOnSave;
  int saveCalls = 0;

  @override
  Future<void> saveState({
    String? lastRoute,
    String? activeTaskId,
    bool clearActiveTask = false,
    String? draftTaskTitle,
  }) async {
    saveCalls += 1;
    if (failOnSave) {
      throw StateError('recovery save test failure');
    }
  }
}

class _FakeMetricsAccumulator extends LocalMetricsAccumulator {
  _FakeMetricsAccumulator({this.failOnSnapshot = false});

  final bool failOnSnapshot;
  int snapshotCalls = 0;

  @override
  Future<Map<String, dynamic>> snapshot() async {
    snapshotCalls += 1;
    if (failOnSnapshot) {
      throw StateError('metrics snapshot test failure');
    }
    return <String, dynamic>{};
  }
}

class _FakeAudioInterruptionService implements AudioInterruptionService {
  _FakeAudioInterruptionService({this.failOnStop = false});

  final bool failOnStop;
  int stopCalls = 0;

  @override
  Future<void> start({
    required Future<void> Function() onInterruptionBegin,
    required Future<void> Function() onBecomingNoisy,
  }) async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (failOnStop) {
      throw StateError('audio shutdown test failure');
    }
  }
}
