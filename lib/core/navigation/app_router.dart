import 'package:fantastic_guacamole/app/navigation_shell.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/focus/ui/focus_screen.dart';
import 'package:fantastic_guacamole/features/home/ui/smart_coach_screen.dart';
import 'package:fantastic_guacamole/features/insights/ui/insight_screen.dart';
import 'package:fantastic_guacamole/features/logs/ui/logs_screen.dart';
import 'package:fantastic_guacamole/features/nexus/ui/nexus_screen.dart';
import 'package:fantastic_guacamole/features/notifications/ui/notification_screen.dart';
import 'package:fantastic_guacamole/features/paywall/ui/paywall_page.dart';
import 'package:fantastic_guacamole/features/plan/ui/plan_screen.dart';
import 'package:fantastic_guacamole/features/profile/ui/profile_screen.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/features/reflect/ui/reflect_screen.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/features/si_console/ui/si_console_screen.dart';
import 'package:fantastic_guacamole/features/tasks/ui/task_screen.dart';
import 'package:flutter/material.dart';

@Deprecated('Use lib/app/router/app_router.dart with GoRouter instead.')
class AppRouter {
  @Deprecated('Use lib/app/router/app_router.dart with GoRouter instead.')
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return createRoute(const NavigationShell());
      case '/coach':
        return createRoute(const SmartCoachScreen());
      case '/focus':
        return createRoute(const FocusScreen());
      case '/plan':
        return createRoute(const PlanScreen());
      case '/create':
        return createRoute(const CreatorScreen());
      case '/reflect':
        return createRoute(const ReflectScreen());
      case '/insights':
        return createRoute(const InsightScreen());
      case '/logs':
        return createRoute(const LogsScreen());
      case '/nexus':
        return createRoute(const NexusScreen());
      case '/notifications':
        return createRoute(const NotificationsPage());
      case '/paywall':
        return createRoute(const PaywallPage());
      case '/progression':
        return createRoute(const ProgressionScreen());
      case '/si':
        return createRoute(const SIConsoleScreen());
      case '/tasks':
        return createRoute(const TaskScreen());
      case '/profile':
        return createRoute(const ProfileScreen());
      case '/settings':
        return createRoute(const SettingsScreen());
      default:
        return createRoute(
          const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}

@Deprecated('Use GoRouter pages from lib/app/router/app_router.dart instead.')
Route<dynamic> createRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
