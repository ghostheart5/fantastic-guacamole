import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
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
    final Decision? decision = appState.decision;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AnimatedSystemBackground()),
          SafeArea(
            child: Column(
              children: <Widget>[
                SystemHeader(
                  sectionTitle: shellTabs[_tabIndex].label,
                  alertCount: (decision?.workload ?? 0) > 0.75 ? 1 : 0,
                ),
                Expanded(child: _centerContent()),
                SystemBottomNav(
                  items: shellTabs
                      .map((ShellTabInfo tab) => SystemNavItem(label: tab.label, icon: tab.icon))
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
}
