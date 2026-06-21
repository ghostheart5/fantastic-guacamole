import 'package:flutter/material.dart';

enum ShellTab { nexus, creator, logs, temporal, siConsole, settings }

class ShellTabInfo {
  const ShellTabInfo({required this.tab, required this.label, required this.icon});

  final ShellTab tab;
  final String label;
  final IconData icon;
}

const List<ShellTabInfo> shellTabs = <ShellTabInfo>[
  ShellTabInfo(tab: ShellTab.nexus, label: 'Nexus', icon: Icons.home_rounded),
  ShellTabInfo(tab: ShellTab.creator, label: 'Creator', icon: Icons.auto_awesome_rounded),
  ShellTabInfo(tab: ShellTab.logs, label: 'Logs', icon: Icons.menu_book_rounded),
  ShellTabInfo(tab: ShellTab.temporal, label: 'Ops', icon: Icons.timeline_rounded),
  ShellTabInfo(tab: ShellTab.siConsole, label: 'SI', icon: Icons.memory_rounded),
  ShellTabInfo(tab: ShellTab.settings, label: 'Settings', icon: Icons.settings_rounded),
];
