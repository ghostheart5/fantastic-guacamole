import 'dart:async';

import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/core/errors/error_boundary_widget.dart';
import 'package:fantastic_guacamole/core/network/network_status_service.dart';
import 'package:fantastic_guacamole/core/widgets/offline_banner.dart';
import 'package:fantastic_guacamole/data/local/offline_queue.dart';
import 'package:fantastic_guacamole/features/coach/ui/coach_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/flowmap/ui/flowmap_screen.dart';
import 'package:fantastic_guacamole/features/focus/ui/focus_screen.dart';
import 'package:fantastic_guacamole/features/goals/ui/goals_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';
import 'package:fantastic_guacamole/features/insights/ui/insight_screen.dart';
import 'package:fantastic_guacamole/features/logs/ui/logs_screen.dart';
import 'package:fantastic_guacamole/features/memories/ui/memories_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/reflect/ui/reflect_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/soul_map/ui/soul_map_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/features/tasks/ui/task_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/focus_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/premium_feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  int _index = 0;
  Timer? _passiveRefreshTimer;
  Timer? _offlineSyncTimer;
  Timer? _aiPrecomputeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _passiveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(aiResponseProvider);
    });

    _offlineSyncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      unawaited(_replayOfflineQueue());
    });

    _aiPrecomputeTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      if (!mounted) return;
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecovery());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passiveRefreshTimer?.cancel();
    _offlineSyncTimer?.cancel();
    _aiPrecomputeTimer?.cancel();
    super.dispose();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveCurrentState());
    } else if (state == AppLifecycleState.resumed) {
      _checkRecovery();
      unawaited(_replayOfflineQueue());
    }
  }

  // ── State Recovery ────────────────────────────────────────────────────────

  Future<void> _saveCurrentState() async {
    if (!mounted) return;
    final view = ref.read(appFlowProvider);
    await ref.read(sessionRecoveryProvider).saveState(lastRoute: view.name);
    unawaited(_pushDailyMetrics());
  }

  Future<void> _pushDailyMetrics() async {
    if (!mounted) return;
    final accumulator = ref.read(localMetricsAccumulatorProvider);
    final snapshot = await accumulator.snapshot();
    await ref.read(globalAggregationServiceProvider).push(snapshot);
  }

  Future<void> _checkRecovery() async {
    if (!mounted) return;
    final recovery = await ref.read(sessionRecoveryProvider).loadState();
    if (recovery == null) return;

    if (recovery.focusSessionActive && recovery.focusStartTime != null) {
      final elapsed = DateTime.now().difference(recovery.focusStartTime!);
      if (elapsed.inHours < 4 && mounted) {
        ref.read(appFlowProvider.notifier).toFocus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resuming focus session'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        await ref.read(sessionRecoveryProvider).clearFocus();
      }
    }
  }

  // ── Offline Queue ─────────────────────────────────────────────────────────

  Future<void> _replayOfflineQueue() async {
    if (!mounted) return;
    final queue = ref.read(offlineQueueProvider);
    await queue.replay((action) async {
      // Actions are fire-and-forget best-effort replays.
      // Task operations are stored locally already; this is for future cloud sync.
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  static const _screens = [
    NexusScreen(),
    TaskScreen(),
    CoachScreen(),
    LogsScreen(),
    ProfileScreen(),
  ];

  BottomNavigationBarItem _svgNavItem(
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

  @override
  Widget build(BuildContext context) {
    // AI re-evaluates automatically after focus completes
    ref.listen<FocusState>(focusControllerProvider, (prev, next) {
      if (prev?.completed == false && next.completed) {
        ref.invalidate(aiDecisionProvider);
        ref.invalidate(aiResponseProvider);
        unawaited(
          ref
              .read(localMetricsAccumulatorProvider)
              .recordFocusSession(
                completed: true,
                durationSeconds: prev?.seconds ?? 0,
              ),
        );
      } else if (prev?.active == true &&
          next.active == false &&
          next.completed == false) {
        final elapsed = prev?.seconds ?? 0;
        if (elapsed > 0) {
          unawaited(
            ref
                .read(localMetricsAccumulatorProvider)
                .recordFocusSession(completed: false, durationSeconds: elapsed),
          );
        }
      }
    });
    ref.listen<double>(energyProvider, (_, _) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });
    ref.listen(learningProvider, (_, _) {
      ref.invalidate(aiDecisionProvider);
      ref.invalidate(aiResponseProvider);
    });

    // Track focus view entry/exit for session recovery
    ref.listen<AppView>(appFlowProvider, (prev, next) {
      if (next == AppView.focus) {
        unawaited(
          ref
              .read(sessionRecoveryProvider)
              .saveState(
                focusSessionActive: true,
                focusStartTime: DateTime.now(),
              ),
        );
      } else if (prev == AppView.focus) {
        unawaited(ref.read(sessionRecoveryProvider).clearFocus());
      }
      unawaited(
        ref.read(sessionRecoveryProvider).saveState(lastRoute: next.name),
      );
    });

    // Replay offline queue when connectivity is restored
    ref.listen<bool>(isOnlineProvider, (prev, next) {
      if (next && prev == false) {
        unawaited(_replayOfflineQueue());
      }
    });

    final view = ref.watch(appFlowProvider);
    final access = ref.watch(appAccessProvider);

    Widget body;
    if (view == AppView.coach) {
      body = Scaffold(
        body: _screens[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            if (i == 2) {
              ref.read(appFlowProvider.notifier).toSmartCoach();
              return;
            }
            setState(() => _index = i);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xD90B111C),
          selectedItemColor: const Color(0xFF00E5FF),
          unselectedItemColor: Colors.white70,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: [
            _svgNavItem(AppAssets.iconNexus, 'Nexus', _index == 0),
            _svgNavItem(AppAssets.iconTasks, 'Tasks', _index == 1),
            _svgNavItem(AppAssets.iconCoach, 'Coach', _index == 2),
            _svgNavItem(AppAssets.iconLogs, 'Logs', _index == 3),
            _svgNavItem(AppAssets.iconProfile, 'Profile', _index == 4),
          ],
        ),
      );
    } else if (view == AppView.smartCoach) {
      body = const ErrorBoundary(child: SmartCoachScreen());
    } else if (view == AppView.focus) {
      body = const ErrorBoundary(child: FocusScreen());
    } else if (view == AppView.insight) {
      body = const InsightScreen();
    } else if (view == AppView.reflect) {
      body = const ReflectScreen();
    } else if (view == AppView.console) {
      body = access.hasPremiumAccess
          ? const SIConsoleScreen()
          : _PremiumRouteGate(
              featureName: 'SI Console',
              onGoToSettings: () =>
                  ref.read(appFlowProvider.notifier).toSettings(),
            );
    } else if (view == AppView.settings) {
      body = const SettingsScreen();
    } else if (view == AppView.progression) {
      body = const ProgressionScreen();
    } else if (view == AppView.plan) {
      body = const PlanScreen();
    } else if (view == AppView.creator) {
      body = const CreatorScreen();
    } else if (view == AppView.flowmap) {
      body = const FlowmapScreen();
    } else if (view == AppView.goals) {
      body = const GoalsScreen();
    } else if (view == AppView.memories) {
      body = const MemoriesScreen();
    } else if (view == AppView.soulMap) {
      body = const SoulMapScreen();
    } else if (view == AppView.timeline) {
      body = const TimelineScreen();
    } else {
      body = const CoachScreen();
    }

    return OfflineBanner(child: body);
  }
}

class _PremiumRouteGate extends StatelessWidget {
  const _PremiumRouteGate({
    required this.featureName,
    required this.onGoToSettings,
  });

  final String featureName;
  final VoidCallback onGoToSettings;

  @override
  Widget build(BuildContext context) {
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSettings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PremiumFeatureGate(
              featureName: featureName,
              onGoToSettings: onGoToSettings,
            ),
          ),
        ),
      ),
    );
  }
}
