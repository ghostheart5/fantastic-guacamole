import 'package:flutter/material.dart';

enum ShellTab { nexus, creator, logs, temporal, siConsole, settings }

class ShellTabInfo {
  const ShellTabInfo({
    required this.tab,
    required this.label,
    required this.icon,
    required this.iconAsset,
  });

  final ShellTab tab;
  final String label;
  final IconData icon;
  final String iconAsset;
}

const List<ShellTabInfo> shellTabs = <ShellTabInfo>[
  ShellTabInfo(
    tab: ShellTab.nexus,
    label: 'ChronoHome',
    icon: Icons.home_rounded,
    iconAsset: 'assets/icons/home_icon.png',
  ),
  ShellTabInfo(
    tab: ShellTab.creator,
    label: 'ChronoCreator',
    icon: Icons.auto_awesome_rounded,
    iconAsset: 'assets/icons/creator_icon.png',
  ),
  ShellTabInfo(
    tab: ShellTab.logs,
    label: 'ChronoLogs',
    icon: Icons.menu_book_rounded,
    iconAsset: 'assets/icons/chronologs_icon.png',
  ),
  ShellTabInfo(
    tab: ShellTab.temporal,
    label: 'Chrono-Ops',
    icon: Icons.timeline_rounded,
    iconAsset: 'assets/icons/ops_icon.png',
  ),
  ShellTabInfo(
    tab: ShellTab.siConsole,
    label: 'SI',
    icon: Icons.memory_rounded,
    iconAsset: 'assets/icons/si_console_icon.png',
  ),
  ShellTabInfo(
    tab: ShellTab.settings,
    label: 'Settings',
    icon: Icons.settings_rounded,
    iconAsset: 'assets/icons/settings_icon.png',
  ),
];
