import 'dart:async';

import 'package:fantastic_guacamole/core/constants/app_assets.dart';
import 'package:fantastic_guacamole/features/coach/ui/coach_screen.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/flowmap/ui/flowmap_screen.dart';
import 'package:fantastic_guacamole/features/focus/ui/focus_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';
import 'package:fantastic_guacamole/features/insights/ui/insight_screen.dart';
import 'package:fantastic_guacamole/features/logs/ui/logs_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/reflect/ui/reflect_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/tasks/ui/task_screen.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/focus_controller.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/access_provider.dart';
import 'package:fantastic_guacamole/state/providers/energy_provider.dart';
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

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _index = 0;
  Timer? _passiveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _passiveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(aiResponseProvider);
    });
  }

  @override
  void dispose() {
    _passiveRefreshTimer?.cancel();
    super.dispose();
  }

  static const _screens = [
    NexusScreen(),
    TaskScreen(),
    ReflectScreen(),
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
    // Passive trigger: AI re-evaluates automatically after focus completes
    ref.listen<FocusState>(focusControllerProvider, (prev, next) {
      if (prev?.completed == false && next.completed) {
        ref.invalidate(aiDecisionProvider);
        ref.invalidate(aiResponseProvider);
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

    final view = ref.watch(appFlowProvider);
    final access = ref.watch(appAccessProvider);

    Widget body;
    if (view == AppView.coach) {
      body = Scaffold(
        body: _screens[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
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
            _svgNavItem(AppAssets.iconReflect, 'Reflect', _index == 2),
            _svgNavItem(AppAssets.iconLogs, 'Logs', _index == 3),
            _svgNavItem(AppAssets.iconProfile, 'Profile', _index == 4),
          ],
        ),
      );
    } else if (view == AppView.smartCoach) {
      body = const SmartCoachScreen();
    } else if (view == AppView.focus) {
      body = const FocusScreen();
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
    } else {
      body = const CoachScreen();
    }

    return body;
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
