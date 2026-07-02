import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChronoSparkBottomNav extends StatelessWidget {
  const ChronoSparkBottomNav({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const List<String> _routes = <String>[
    RoutePaths.home,
    RoutePaths.creator,
    RoutePaths.logs,
    RoutePaths.progression,
    RoutePaths.si,
    RoutePaths.settings,
  ];

  void _onSelect(BuildContext context, int index) {
    if (index == selectedIndex) {
      return;
    }
    context.go(_routes[index]);
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
        NavigationDestination(icon: Icon(Icons.timeline), label: 'Progress'),
        NavigationDestination(icon: Icon(Icons.psychology_alt), label: 'SI'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }
}
