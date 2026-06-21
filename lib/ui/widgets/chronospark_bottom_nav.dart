import 'package:flutter/material.dart';

class ChronoSparkBottomNav extends StatelessWidget {
  const ChronoSparkBottomNav({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const List<String> _routes = <String>[
    '/',
    '/creator',
    '/logs',
    '/temporal',
    '/si',
    '/settings',
  ];

  void _onSelect(BuildContext context, int index) {
    if (index == selectedIndex) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (int index) => _onSelect(context, index),
      destinations: const <NavigationDestination>[
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Creator'),
        NavigationDestination(icon: Icon(Icons.history_edu), label: 'Logs'),
        NavigationDestination(icon: Icon(Icons.timeline), label: 'Ops'),
        NavigationDestination(icon: Icon(Icons.psychology_alt), label: 'SI'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
