import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/flowmap/ui/flowmap_screen.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';
import 'package:fantastic_guacamole/features/insights/ui/insight_screen.dart';
import 'package:fantastic_guacamole/features/logs/ui/logs_screen.dart';
import 'package:fantastic_guacamole/features/memories/ui/memories_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/soul_map/ui/soul_map_screen.dart';
import 'package:fantastic_guacamole/features/tasks/ui/task_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/session_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key, this.initialView = AppView.coach, this.initialTabIndex = 0});

  final AppView initialView;
  final int initialTabIndex;

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> with WidgetsBindingObserver {
  late int _index;
  late final SystemScheduler _systemScheduler;
  late final DataHygieneScheduler _dataHygieneScheduler;
  late final ProviderSubscription<double> _energySubscription;
  late final ProviderSubscription<LearningState> _learningSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;

  static const List<Widget> _screens = <Widget>[
    NexusScreen(),
    TaskScreen(),
    LogsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialTabIndex.clamp(0, _screens.length - 1);
    WidgetsBinding.instance.addObserver(this);
    _systemScheduler = SystemScheduler()
      ..onSyncOfflineQueue = () {
        if (!mounted || !Env.enableCloudSync) {
          return;
        }
        ref.invalidate(replayOfflineQueueProvider);
        ref.invalidate(syncToCloudProvider);
      }
      ..onPrecomputeAI = () {
        if (mounted) {
          ref.invalidate(aiDecisionProvider);
        }
      }
      ..resume();
    _dataHygieneScheduler = ref.read(dataHygieneSchedulerProvider)..start();
    _energySubscription = ref.listenManual<double>(energyProvider, (_, _) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });
    _learningSubscription = ref.listenManual<LearningState>(learningProvider, (_, _) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });
    _viewSubscription = ref.listenManual<AppView>(appFlowProvider, (_, AppView next) {
      unawaited(ref.read(sessionRecoveryProvider).saveState(lastRoute: next.name));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appFlowProvider.notifier).show(widget.initialView);
      _checkRecovery();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _systemScheduler.shutdown();
    _dataHygieneScheduler.shutdown();
    _energySubscription.close();
    _learningSubscription.close();
    _viewSubscription.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final int nextIndex = widget.initialTabIndex.clamp(0, _screens.length - 1);
      if (_index != nextIndex) {
        setState(() => _index = nextIndex);
      }
    }

    if (oldWidget.initialView != widget.initialView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(appFlowProvider.notifier).show(widget.initialView);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        _systemScheduler.shutdown();
        _dataHygieneScheduler.shutdown();
        unawaited(_saveCurrentState());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _systemScheduler.pause();
        _dataHygieneScheduler.pause();
        unawaited(_saveCurrentState());
        break;
      case AppLifecycleState.resumed:
        _systemScheduler.resume();
        _dataHygieneScheduler.start();
        unawaited(_checkRecovery());
        break;
    }
  }

  Future<void> _saveCurrentState() async {
    if (!mounted) {
      return;
    }
    final AppView view = ref.read(appFlowProvider);
    await ref.read(sessionRecoveryProvider).saveState(lastRoute: view.name);
    unawaited(_pushDailyMetrics());
  }

  Future<void> _pushDailyMetrics() async {
    if (!mounted) {
      return;
    }
    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final Map<String, dynamic> snapshot = await accumulator.snapshot();
    await ref.read(globalAggregationServiceProvider).push(snapshot);
  }

  Future<void> _checkRecovery() async {
    if (!mounted) {
      return;
    }
    final recovery = await ref.read(sessionRecoveryProvider).loadState();
    if (!mounted || recovery == null) {
      return;
    }
    final AppView? recoveredView = appViewFromName(recovery.lastRoute);
    if (recoveredView != null) {
      ref.read(appFlowProvider.notifier).show(recoveredView);
    }
  }

  BottomNavigationBarItem _navItem(String assetPath, String label, bool active) {
    return BottomNavigationBarItem(
      label: label,
      icon: SvgPicture.asset(
        assetPath,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          active ? const Color(0xFF00E5FF) : Colors.white70,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppView view = ref.watch(appFlowProvider);

    final Widget body = switch (view) {
      AppView.coach => Scaffold(
        body: _screens[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (int index) => setState(() => _index = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xD90B111C),
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.white70,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: <BottomNavigationBarItem>[
            _navItem(AppAssets.iconNexus, 'Nexus', _index == 0),
            _navItem(AppAssets.iconTasks, 'Trajectory', _index == 1),
            _navItem(AppAssets.iconLogs, 'Ledger', _index == 2),
            _navItem(AppAssets.iconProfile, 'Profile', _index == 3),
          ],
        ),
      ),
      AppView.smartCoach => const SmartCoachScreen(),
      AppView.insight => const InsightScreen(),
      AppView.console => const SIConsoleScreen(),
      AppView.settings => const SettingsScreen(),
      AppView.progression => const ProgressionScreen(),
      AppView.plan => const PlanScreen(),
      AppView.creator => const CreatorScreen(),
      AppView.flowmap => const FlowmapScreen(),
      AppView.goals => const GoalsScreen(),
      AppView.memories => const MemoriesScreen(),
      AppView.soulMap => const SoulMapScreen(),
      AppView.timeline => const TimelineScreen(),
    };

    return OfflineBanner(child: body);
  }
}
