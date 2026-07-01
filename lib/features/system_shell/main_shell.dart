import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../ui/system/animated_system_background.dart';
import '../../ui/system/premium_feature_gate.dart';
import '../../ui/system/system_bottom_nav.dart';
import '../../ui/system/system_header.dart';
import 'models/shell_tab.dart';
import 'pages/chronocreator_page.dart';
import 'pages/chronologs_page.dart';
import 'pages/nexus_page.dart';
import 'pages/settings_page.dart';
import 'pages/si_console_page.dart';
import 'pages/temporal_ops_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  String? _lastShownNotificationId;

  void _showLatestNotificationIfNeeded(AppState appState, bool notificationsEnabled) {
    if (!notificationsEnabled || appState.notifications.isEmpty) {
      return;
    }

    final notification = appState.notifications.first;
    if (_lastShownNotificationId == notification.id) {
      return;
    }
    _lastShownNotificationId = notification.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification.message),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  Future<void> _openTab(int index) async {
    if (_tabIndex == index) {
      return;
    }
    final AppState appState = context.read<AppState>();
    final ShellTab targetTab = shellTabs[index].tab;

    if (targetTab == ShellTab.temporal && !appState.isPremium) {
      final bool allowed = await appState.consumeTemporalOpsTrialIfNeeded();
      if (!allowed) {
        if (!mounted) {
          return;
        }
        setState(() {
          _tabIndex = shellTabs.indexWhere((ShellTabInfo s) => s.tab == ShellTab.settings);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Temporal Ops free testing is finished. Upgrade to continue.'),
          ),
        );
        return;
      }
    }

    if (targetTab == ShellTab.siConsole && !appState.isPremium) {
      final bool allowed = await appState.consumeSiConsoleTrialIfNeeded();
      if (!allowed) {
        if (!mounted) {
          return;
        }
        setState(() {
          _tabIndex = shellTabs.indexWhere((ShellTabInfo s) => s.tab == ShellTab.settings);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SI Console free testing is finished. Upgrade to continue.'),
          ),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _tabIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final SettingsController settingsController = context.watch<SettingsController>();
    final SettingsState settings = settingsController.read();
    final Decision? decision = appState.decision;

    appState.setNotificationDeliveryEnabled(settings.notifications);
    _showLatestNotificationIfNeeded(appState, settings.notifications);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedSystemBackground(
              backgroundAsset: _backgroundAssetForTab(shellTabs[_tabIndex].tab),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                SystemHeader(
                  sectionTitle: shellTabs[_tabIndex].label,
                  icon: shellTabs[_tabIndex].icon,
                  iconAsset: shellTabs[_tabIndex].iconAsset,
                  alertCount: (decision?.workload ?? 0) > 0.75 ? 1 : 0,
                ),
                Expanded(child: _centerContent()),
                SystemBottomNav(
                  items: shellTabs
                      .map(
                        (ShellTabInfo tab) => SystemNavItem(
                          label: tab.label,
                          icon: tab.icon,
                          iconAsset: tab.iconAsset,
                        ),
                      )
                      .toList(),
                  currentIndex: _tabIndex,
                  onTap: (int index) async {
                    await _openTab(index);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerContent() {
    final AppState appState = context.read<AppState>();

    switch (shellTabs[_tabIndex].tab) {
      case ShellTab.nexus:
        return NexusPage(
          onPortalTap: (int index) async {
            await _openTab(index);
          },
        );
      case ShellTab.creator:
        return const ChronoCreatorPage();
      case ShellTab.logs:
        return const ChronoLogsPage();
      case ShellTab.temporal:
        if (!appState.canUseTemporalOps) {
          return PremiumFeatureGate(
            featureName: 'Temporal Ops',
            subtitle:
                'Base trial remaining: ${appState.temporalTrialRemaining}. Upgrade for unlimited access.',
            currentPlan: appState.currentPlan,
            onGoToSettings: () {
              setState(() {
                _tabIndex = shellTabs.indexWhere((ShellTabInfo s) => s.tab == ShellTab.settings);
              });
            },
          );
        }
        return const TemporalOpsPage();
      case ShellTab.siConsole:
        if (!appState.canUseSiConsole) {
          return PremiumFeatureGate(
            featureName: 'SI Console',
            subtitle:
                'Base trial remaining: ${appState.siConsoleTrialRemaining}. Upgrade for unlimited access.',
            currentPlan: appState.currentPlan,
            onGoToSettings: () {
              setState(() {
                _tabIndex = shellTabs.indexWhere((ShellTabInfo s) => s.tab == ShellTab.settings);
              });
            },
          );
        }
        return const SiConsolePage();
      case ShellTab.settings:
        return const SettingsPage();
    }
  }

  String _backgroundAssetForTab(ShellTab tab) {
    switch (tab) {
      case ShellTab.nexus:
        return 'assets/backgrounds/main_bg.png';
      case ShellTab.creator:
        return 'assets/backgrounds/chronocreator_bg.png';
      case ShellTab.logs:
        return 'assets/backgrounds/main_bg.png';
      case ShellTab.temporal:
        return 'assets/backgrounds/temporal_bg.png';
      case ShellTab.siConsole:
        return 'assets/backgrounds/si_console_bg.png';
      case ShellTab.settings:
        return 'assets/backgrounds/settings_bg.png';
    }
  }
}
