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
  const NavigationShell({super.key, this.initialView = AppView.nexus});

  final AppView initialView;

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  late final SystemScheduler _systemScheduler;
  late final DataHygieneScheduler _dataHygieneScheduler;
  late final ProviderSubscription<double> _energySubscription;
  late final ProviderSubscription<LearningState> _learningSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;
  final Set<int> _initializedTabIndexes = <int>{0};
  bool get _isFlutterTestBinding {
    final String bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
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
      };
    if (!_isFlutterTestBinding) {
      _systemScheduler.resume();
    }
    _dataHygieneScheduler = ref.read(dataHygieneSchedulerProvider);
    if (!_isFlutterTestBinding) {
      _dataHygieneScheduler.start();
    }
    _energySubscription = ref.listenManual<double>(energyProvider, (_, _) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });
    _learningSubscription = ref.listenManual<LearningState>(learningProvider, (
      _,
      _,
    ) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });
    _viewSubscription = ref.listenManual<AppView>(appFlowProvider, (
      _,
      AppView next,
    ) {
      _initializedTabIndexes.add(_tabIndexForView(next));
      unawaited(
        ref.read(sessionRecoveryProvider).saveState(lastRoute: next.name),
      );
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
        if (!_isFlutterTestBinding) {
          _systemScheduler.pause();
          _dataHygieneScheduler.pause();
        }
        unawaited(_saveCurrentState());
        break;
      case AppLifecycleState.resumed:
        if (!_isFlutterTestBinding) {
          _systemScheduler.resume();
          _dataHygieneScheduler.start();
        }
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

  BottomNavigationBarItem _navItem(
    String assetPath,
    String label,
    bool active,
  ) {
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

  int _tabIndexForView(AppView view) {
    return switch (view) {
      AppView.coach || AppView.nexus => 0,
      AppView.tasks => 1,
      AppView.logs => 2,
      AppView.profile => 3,
      _ => 0,
    };
  }

  void _onTabSelected(int index) {
    _initializedTabIndexes.add(index);
    final AppFlowController controller = ref.read(appFlowProvider.notifier);
    switch (index) {
      case 0:
        controller.toNexus();
      case 1:
        controller.toTasks();
      case 2:
        controller.toLogs();
      case 3:
        controller.toProfile();
    }
  }

  Widget _buildTabbedBody(int tabIndex) {
    Widget tabAt(int index) {
      if (!_initializedTabIndexes.contains(index)) {
        return const SizedBox.shrink();
      }
      return switch (index) {
        1 => const TaskScreen(),
        2 => const LogsScreen(),
        3 => const ProfileScreen(),
        _ => const NexusScreen(),
      };
    }

    return IndexedStack(
      index: tabIndex,
      children: <Widget>[tabAt(0), tabAt(1), tabAt(2), tabAt(3)],
    );
  }

  void _showNavigationMap() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        Widget navItem(String title, String subtitle, AppView target) {
          return ListTile(
            dense: true,
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pop();
              ref.read(appFlowProvider.notifier).show(target);
            },
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
            children: [
              const ListTile(
                title: Text('Navigation Map'),
                subtitle: Text('Core first, advanced when needed.'),
              ),
              const Divider(),
              navItem('Nexus', 'Main command center', AppView.nexus),
              navItem('Trajectory', 'Task execution lane', AppView.tasks),
              navItem('Ledger', 'Logs and review trail', AppView.logs),
              navItem('Profile', 'Identity and progression', AppView.profile),
              const Divider(),
              navItem('Plan', 'Adaptive schedule', AppView.plan),
              navItem('Creator', 'Task and goal creation', AppView.creator),
              navItem(
                'Insights',
                'Pattern and trend analysis',
                AppView.insight,
              ),
              navItem('Settings', 'Preferences and controls', AppView.settings),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppView view = ref.watch(appFlowProvider);
    final int tabIndex = _tabIndexForView(view);
    _initializedTabIndexes.add(tabIndex);

    final Widget body = switch (view) {
      AppView.coach ||
      AppView.nexus ||
      AppView.tasks ||
      AppView.logs ||
      AppView.profile => Scaffold(
        floatingActionButton: FloatingActionButton.small(
          onPressed: _showNavigationMap,
          child: const Icon(Icons.map_outlined),
        ),
        body: _buildTabbedBody(tabIndex),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: tabIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xD90B111C),
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.white70,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: <BottomNavigationBarItem>[
            _navItem(AppAssets.iconNexus, 'Nexus', tabIndex == 0),
            _navItem(AppAssets.iconTasks, 'Trajectory', tabIndex == 1),
            _navItem(AppAssets.iconLogs, 'Ledger', tabIndex == 2),
            _navItem(AppAssets.iconProfile, 'Profile', tabIndex == 3),
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
