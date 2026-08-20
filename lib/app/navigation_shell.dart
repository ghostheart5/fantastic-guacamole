import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_planner_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/trajectory_engine/ui/trajectory_engine_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/app_recovery_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:fantastic_guacamole/state/services/data_hygiene_scheduler.dart';
import 'package:fantastic_guacamole/state/services/preference_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/system/voice/audio_interruption_service.dart';
import 'package:fantastic_guacamole/system/system_scheduler.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({
    super.key,
    this.initialView = AppView.nexus,
    this.allowSavedTabRestore = false,
  });

  final AppView initialView;
  final bool allowSavedTabRestore;

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  final PreferenceService _preferenceService = PreferenceService();
  late final SystemScheduler _systemScheduler;
  late final DataHygieneScheduler _dataHygieneScheduler;
  late final AudioInterruptionService _audioInterruptionService;
  late final ProviderSubscription<double> _energySubscription;
  late final ProviderSubscription<LearningState> _learningSubscription;
  late final ProviderSubscription<AppView> _viewSubscription;
  late final ProviderSubscription<bool> _networkOnlineSubscription;
  final Set<int> _initializedTabIndexes = <int>{};
  bool _savingCurrentState = false;
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
      };
    if (!_isFlutterTestBinding) {
      _systemScheduler.resume();
    }
    _dataHygieneScheduler = ref.read(dataHygieneSchedulerProvider);
    if (!_isFlutterTestBinding) {
      _dataHygieneScheduler.start();
    }
    _audioInterruptionService = ref.read(audioInterruptionServiceProvider);
    if (!_isFlutterTestBinding) {
      unawaited(
        _audioInterruptionService.start(
          onInterruptionBegin: _stopVoicePlayback,
          // A wired headset's removal doesn't affect the device's own mic, so
          // only TTS needs to stop here — otherwise it would suddenly route
          // to the speaker.
          onBecomingNoisy: () => ref.read(voiceServiceProvider).stop(),
        ),
      );
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
      unawaited(ref.read(appRecoveryProvider).saveState(lastRoute: next.name));
    });
    _networkOnlineSubscription = ref.listenManual<bool>(isOnlineProvider, (
      bool? previous,
      bool next,
    ) {
      final bool cameBackOnline =
          next && (previous == null || previous == false);
      if (!cameBackOnline) {
        return;
      }
      _triggerCloudSyncReplay();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.allowSavedTabRestore) {
        _restoreDefaultLaunchTab();
      } else {
        _syncAppFlowToRouteView(widget.initialView);
      }
      unawaited(_handleNotificationLaunch());
    });
    NotificationScheduler.tappedPayloadListenable.addListener(
      _onNotificationTapped,
    );
  }

  /// Routes a notification tap that arrived while the app was running.
  void _onNotificationTapped() {
    final String? payload = NotificationScheduler.tappedPayloadListenable.value;
    if (payload == null || !mounted) {
      return;
    }
    NotificationScheduler.tappedPayloadListenable.value = null;
    _routeNotificationPayload(payload);
  }

  /// Routes a cold launch that came from a notification tap.
  Future<void> _handleNotificationLaunch() async {
    final String? payload = await NotificationScheduler()
        .consumeLaunchPayload();
    if (payload == null || !mounted) {
      return;
    }
    _routeNotificationPayload(payload);
  }

  /// Maps a notification payload (the domain notification id) to a screen.
  ///
  /// Ids are namespaced by the services that create them; anything
  /// unrecognised falls back to the notifications list rather than being
  /// dropped, which is what happened before — no response handler existed at
  /// all, so a tap only ever opened the app on whatever tab it was last on.
  void _routeNotificationPayload(String payload) {
    if (payload.startsWith('goal_reminder_')) {
      _goToView(AppView.goals);
      return;
    }
    if (payload.startsWith('daily_planning_reminder')) {
      _goToView(AppView.timeline);
      return;
    }
    if (payload.startsWith('habit_reminder')) {
      _goToView(AppView.creator);
      return;
    }
    if (payload.startsWith('reflection_reminder')) {
      _goToView(AppView.timeline);
      return;
    }
    if (payload.startsWith('streak_break_recovery_')) {
      _goToView(AppView.progression);
      return;
    }
    _goToView(AppView.timeline);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationScheduler.tappedPayloadListenable.removeListener(
      _onNotificationTapped,
    );
    _systemScheduler.shutdown();
    _dataHygieneScheduler.shutdown();
    unawaited(_audioInterruptionService.stop());
    _energySubscription.close();
    _learningSubscription.close();
    _viewSubscription.close();
    _networkOnlineSubscription.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialView != widget.initialView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncAppFlowToRouteView(widget.initialView);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        _systemScheduler.shutdown();
        _dataHygieneScheduler.shutdown();
        unawaited(_stopVoicePlayback());
        unawaited(_saveCurrentState());
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!_isFlutterTestBinding) {
          _systemScheduler.pause();
          _dataHygieneScheduler.pause();
        }
        // Otherwise a long SI response or planner summary keeps speaking over
        // whatever the user does next after backgrounding the app.
        unawaited(_stopVoicePlayback());
        unawaited(_saveCurrentState());
        break;
      case AppLifecycleState.resumed:
        if (!_isFlutterTestBinding) {
          _systemScheduler.resume();
          _dataHygieneScheduler.start();
        }
        _syncAppFlowToRouteView(widget.initialView);
        break;
    }
  }

  Future<void> _stopVoicePlayback() async {
    if (!mounted) {
      return;
    }
    try {
      await ref.read(voiceServiceProvider).stop();
    } on Object {
      // Never let a TTS engine failure interfere with lifecycle handling.
    }
    try {
      // An open mic capture must not survive the app being backgrounded.
      await ref.read(voiceControllerProvider.notifier).stopListening();
    } on Object {
      // Never let an STT engine failure interfere with lifecycle handling.
    }
  }

  Future<void> _saveCurrentState() async {
    if (!mounted || _savingCurrentState) {
      return;
    }
    _savingCurrentState = true;
    try {
      final AppView view = widget.initialView;
      await ref.read(appRecoveryProvider).saveState(lastRoute: view.name);
      unawaited(_pushDailyMetrics());
    } finally {
      _savingCurrentState = false;
    }
  }

  Future<void> _pushDailyMetrics() async {
    if (!mounted) {
      return;
    }
    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final Map<String, dynamic> snapshot = await accumulator.snapshot();
    await ref.read(globalAggregationServiceProvider).push(snapshot);
  }

  void _syncAppFlowToRouteView(AppView view) {
    _initializedTabIndexes.add(_tabIndexForView(view));
    if (ref.read(appFlowProvider) != view) {
      ref.read(appFlowProvider.notifier).show(view);
    }
  }

  void _restoreDefaultLaunchTab() {
    final int? restoredTab = _preferenceService.getLastOpenedTab();
    final AppView restoredView =
        restoredTab == null || restoredTab < 0 || restoredTab > 3
        ? AppView.nexus
        : _viewForTabIndex(restoredTab);
    _goToView(restoredView);
  }

  void _goToView(AppView view) {
    final String routePath = routePathForAppView(view);
    try {
      final GoRouter router = GoRouter.of(context);
      final Uri currentUri = router.routeInformationProvider.value.uri;
      if (currentUri.path != routePath || currentUri.hasQuery) {
        router.go(routePath);
      }
      return;
    } on Object {
      // Widget tests and standalone shell previews may mount the shell without
      // a GoRouter. Only those previews use the compatibility provider.
    }
    _syncAppFlowToRouteView(view);
  }

  void _triggerCloudSyncReplay() {
    if (!mounted || !Env.enableCloudSync) {
      return;
    }
    ref.invalidate(replayOfflineQueueProvider);
    ref.invalidate(syncToCloudProvider);
    ref.invalidate(offlineQueueCountProvider);
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
      AppView.nexus => 0,
      AppView.trajectoryEngine => 1,
      AppView.timeline => 2,
      AppView.profile => 3,
      _ => 0,
    };
  }

  AppView _viewForTabIndex(int index) {
    return switch (index) {
      1 => AppView.trajectoryEngine,
      2 => AppView.timeline,
      3 => AppView.profile,
      _ => AppView.nexus,
    };
  }

  void _onTabSelected(int index) {
    _initializedTabIndexes.add(index);
    _goToView(_viewForTabIndex(index));
  }

  Widget _buildTabbedBody(int tabIndex) {
    Widget tabAt(int index) {
      if (!_initializedTabIndexes.contains(index)) {
        return const SizedBox.shrink();
      }
      return switch (index) {
        1 => const TrajectoryEngineScreen(),
        2 => const TimelineScreen(),
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
              _goToView(target);
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
              navItem('Nexus', 'Connected planning home', AppView.nexus),
              navItem(
                'Trajectory Engine',
                'Future scenarios and execution',
                AppView.trajectoryEngine,
              ),
              navItem(
                'Timeline',
                'Decision memory and context history',
                AppView.timeline,
              ),
              navItem('Profile', 'Identity and progression', AppView.profile),
              const Divider(),
              navItem(
                'Creator',
                'Turn intention into connected action',
                AppView.creator,
              ),
              navItem(
                'Smart Planner',
                'Reconcile constraints into a next move',
                AppView.smartPlanner,
              ),
              navItem(
                'SI Console',
                'Turn context into a decision brief',
                AppView.console,
              ),
              navItem(
                'Progression',
                'See capabilities built through action',
                AppView.progression,
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
    final AppView view = widget.initialView;
    final int tabIndex = _tabIndexForView(view);
    _initializedTabIndexes.add(tabIndex);

    final Widget body = switch (view) {
      AppView.nexus ||
      AppView.profile ||
      AppView.trajectoryEngine ||
      AppView.timeline => Scaffold(
        floatingActionButton: FloatingActionButton.small(
          onPressed: _showNavigationMap,
          tooltip: 'Open navigation map',
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
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: <BottomNavigationBarItem>[
            _navItem(AppAssets.iconNexus, 'Nexus', tabIndex == 0),
            _navItem(AppAssets.iconTasks, 'Trajectory Engine', tabIndex == 1),
            _navItem(AppAssets.iconLogs, 'Timeline', tabIndex == 2),
            _navItem(AppAssets.iconProfile, 'Profile', tabIndex == 3),
          ],
        ),
      ),
      AppView.smartPlanner => const SmartPlannerScreen(),
      AppView.console => const SIConsoleScreen(),
      AppView.settings => const SettingsScreen(),
      AppView.progression => const ProgressionScreen(),
      AppView.creator => const CreatorScreen(),
      AppView.goals => const GoalsScreen(),
    };

    return PopScope(
      canPop: view == AppView.nexus,
      onPopInvokedWithResult: (bool didPop, dynamic _) {
        if (didPop) {
          return;
        }
        final AppView current = widget.initialView;

        if (current != AppView.nexus &&
            current != AppView.profile &&
            current != AppView.trajectoryEngine &&
            current != AppView.timeline) {
          _goToView(AppView.nexus);
          return;
        }

        if (current == AppView.profile) {
          _goToView(AppView.nexus);
          return;
        }

        SystemNavigator.pop();
      },
      child: OfflineBanner(child: body),
    );
  }
}
